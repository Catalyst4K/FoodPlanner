//
//  DataManager.swift
//  FoodPlanner
//
//  Created by Callum Jones on 07/05/2025.
//

import SwiftUI
import Firebase
import FirebaseFirestore

class DataManager: ObservableObject {
    @Published var userRecipes: [Recipe] = []
    @Published var sharedRecipes: [Recipe] = []
    @Published var pantryIngredients: [IngredientItem] = []
    @Published var shoppingListIngredients: [IngredientItem] = []
    @Published var errorMessage: String?

    let currentUserId: String
    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []

    // Per-listener fetch tasks. When a snapshot arrives, we cancel the previous fetch task
    // so a slow older snapshot can't overwrite a newer one (listener race).
    private var userRecipesFetchTask: Task<Void, Never>?
    private var sharedRecipesFetchTask: Task<Void, Never>?
    private var pantryFetchTask: Task<Void, Never>?
    private var shoppingFetchTask: Task<Void, Never>?

    init(userId: String) {
        self.currentUserId = userId
        listenToUserRecipes()
        listenToSharedRecipes()
        listenToPantry()
        listenToShoppingList()
    }

    deinit {
        listeners.forEach { $0.remove() }
    }

    @MainActor
    private func report(_ error: Error, context: String) {
        let message = "\(context): \(error.localizedDescription)"
        print(message)
        errorMessage = message
    }

    @MainActor
    func clearError() {
        errorMessage = nil
    }

    // MARK: - Recipes (owned by current user)

    private func listenToUserRecipes() {
        let ref = db.collection("Users").document(currentUserId).collection("Recipes")
        let registration = ref.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("Error fetching user recipes: \(error.localizedDescription)")
                return
            }
            guard let docs = snapshot?.documents else { return }

            self.userRecipesFetchTask?.cancel()
            self.userRecipesFetchTask = Task { [weak self] in
                guard let self = self else { return }
                let recipes = await self.buildRecipes(from: docs)
                if Task.isCancelled { return }
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.25)) {
                        self.userRecipes = recipes
                    }
                }
            }
        }
        listeners.append(registration)
    }

    private func listenToSharedRecipes() {
        let query = db.collectionGroup("Recipes").whereField("IsShared", isEqualTo: true)
        let registration = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                // Surface loudly — the most common cause here is a missing composite index that
                // Firestore prompts for on first query. Its console URL is in the underlying error.
                print("Error fetching shared recipes: \(error.localizedDescription)")
                Task { await self.report(error, context: "Shared recipes") }
                return
            }
            guard let docs = snapshot?.documents else { return }

            self.sharedRecipesFetchTask?.cancel()
            self.sharedRecipesFetchTask = Task { [weak self] in
                guard let self = self else { return }
                let recipes = await self.buildRecipes(from: docs)
                if Task.isCancelled { return }
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.25)) {
                        // Exclude the current user's own recipes; they're already in userRecipes.
                        self.sharedRecipes = recipes.filter { $0.ownerId != self.currentUserId }
                    }
                }
            }
        }
        listeners.append(registration)
    }

    private func buildRecipes(from docs: [QueryDocumentSnapshot]) async -> [Recipe] {
        // Sort newest-first by CreatedAt. Use `.estimate` so freshly-written docs whose
        // server timestamp hasn't resolved yet sort at their eventual position (avoids
        // a visible jump when the server confirms). Docs missing CreatedAt go to the end.
        let sortedDocs = docs.sorted { a, b in
            let aTime = (a.data(with: .estimate)["CreatedAt"] as? Timestamp)?.dateValue() ?? .distantPast
            let bTime = (b.data(with: .estimate)["CreatedAt"] as? Timestamp)?.dateValue() ?? .distantPast
            return aTime > bTime
        }

        return await withTaskGroup(of: (Int, Recipe?).self) { group in
            for (index, doc) in sortedDocs.enumerated() {
                group.addTask { [weak self] in
                    let recipe = await self?.parseRecipeDoc(doc)
                    return (index, recipe)
                }
            }
            var indexed: [(Int, Recipe)] = []
            for await (index, recipe) in group {
                if let recipe = recipe { indexed.append((index, recipe)) }
            }
            return indexed.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }

    private func parseRecipeDoc(_ doc: QueryDocumentSnapshot) async -> Recipe? {
        let data = doc.data()
        guard let title = data["Name"] as? String,
              let instructions = data["Instructions"] as? String else {
            print("Skipping recipe with missing fields: \(doc.reference.path)")
            return nil
        }
        // OwnerId derived from path if not present (for legacy or resilience)
        let ownerId = (data["OwnerId"] as? String)
            ?? doc.reference.parent.parent?.documentID
            ?? ""
        let isShared = data["IsShared"] as? Bool ?? false

        let ingredients = await fetchRecipeIngredients(subcollection: doc.reference.collection("Ingredients"))
        return Recipe(
            id: doc.documentID,
            title: title,
            ingredients: ingredients,
            instructions: instructions,
            ownerId: ownerId,
            isShared: isShared
        )
    }

    private func fetchRecipeIngredients(subcollection: CollectionReference) async -> [IngredientItem] {
        do {
            let snap = try await subcollection.getDocuments()
            // Recipe ingredients are ordered by the explicit `Order` index written on each doc,
            // so the list stays in the order the user entered rather than the arbitrary doc-ID
            // order Firestore would otherwise return. Legacy docs without `Order` sort to the end.
            let sortedDocs = snap.documents.sorted { a, b in
                let aOrder = (a.data()["Order"] as? Int) ?? Int.max
                let bOrder = (b.data()["Order"] as? Int) ?? Int.max
                if aOrder != bOrder { return aOrder < bOrder }
                return a.documentID < b.documentID
            }
            return await fetchIngredientsPreservingOrder(from: sortedDocs, refField: "Ref")
        } catch {
            print("Error fetching ingredients from \(subcollection.path): \(error.localizedDescription)")
            return []
        }
    }

    /// Same per-doc parallel fetch as `fetchIngredients`, but skips the CreatedAt sort — the caller
    /// has already sorted the docs in the required order (e.g. by `Order` for recipe subcollections).
    private func fetchIngredientsPreservingOrder(from sortedDocs: [QueryDocumentSnapshot], refField: String) async -> [IngredientItem] {
        return await withTaskGroup(of: (Int, IngredientItem?).self) { group in
            for (index, doc) in sortedDocs.enumerated() {
                guard let ref = doc.data()[refField] as? DocumentReference else { continue }
                let quantity = doc.data()["Quantity"] as? Double
                let unit = doc.data()["Unit"] as? String
                group.addTask { [weak self] in
                    let item = await self?.fetchIngredient(from: ref, quantity: quantity, unit: unit)
                    return (index, item)
                }
            }
            var indexed: [(Int, IngredientItem)] = []
            for await (index, item) in group {
                if let item = item { indexed.append((index, item)) }
            }
            return indexed.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }

    func addRecipe(recipe: Recipe) async {
        let userRecipesRef = db.collection("Users").document(currentUserId).collection("Recipes")
        let newRecipeRef = userRecipesRef.document()

        // Resolve all ingredients in parallel (case-insensitive dedup on /Ingredients).
        // Tag each with its original index and re-sort: a task group yields results in
        // completion order, so without this the `Order` written below would reflect network
        // timing rather than the user's entered order, scrambling the list on read-back.
        let pending = await resolveIngredientsPreservingOrder(recipe.ingredients)

        do {
            // Write the Ingredients subcollection FIRST. Subcollection writes don't require the
            // parent doc to exist, and importantly they don't trigger the /Users/{uid}/Recipes
            // listener — so we avoid a snapshot where the recipe exists with zero ingredients.
            // Each ingredient is tagged with an explicit `Order` index so the list preserves the
            // user's insertion order on read (subcollection docs have no inherent order otherwise
            // and would come back shuffled by doc-ID). Writes run in parallel to minimise latency
            // before the parent recipe write fires the listener.
            let ingredientSubRef = newRecipeRef.collection("Ingredients")
            try await withThrowingTaskGroup(of: Void.self) { group in
                for (index, entry) in pending.enumerated() {
                    group.addTask {
                        var data: [String: Any] = ["Ref": entry.ref, "Order": index]
                        if let quantity = entry.quantity { data["Quantity"] = quantity }
                        if let unit = entry.unit, !unit.isEmpty { data["Unit"] = unit }
                        try await ingredientSubRef.addDocument(data: data)
                    }
                }
                try await group.waitForAll()
            }

            // Now write the recipe doc; the listener fires once with the ingredients already there.
            try await newRecipeRef.setData([
                "Name": recipe.title,
                "Instructions": recipe.instructions,
                "OwnerId": currentUserId,
                "IsShared": false,
                "CreatedAt": FieldValue.serverTimestamp()
            ])
            print("Recipe successfully added.")
        } catch {
            await report(error, context: "Adding recipe")
        }
    }

    /// Updates an existing recipe's title, instructions, and ingredients. Ingredients subcollection is
    /// replaced wholesale (delete + rewrite). The recipe doc is touched last so the listener refires
    /// only after the subcollection is in its final state.
    func updateRecipe(recipeId: String, recipe: Recipe) async {
        let recipeRef = db.collection("Users").document(currentUserId).collection("Recipes").document(recipeId)
        let ingredientSubRef = recipeRef.collection("Ingredients")

        // Resolve ingredients (dedup /Ingredients) in parallel, preserving the user's entered
        // order (see resolveIngredientsPreservingOrder) so the `Order` written below is correct.
        let pending = await resolveIngredientsPreservingOrder(recipe.ingredients)

        do {
            // Replace the Ingredients subcollection. Deletes and adds both run in parallel to
            // minimise the delay before the parent recipe write fires the listener. Each new
            // ingredient is tagged with an explicit `Order` index so insertion order survives
            // the round-trip (subcollection docs otherwise come back shuffled by doc-ID).
            let existing = try await ingredientSubRef.getDocuments()
            try await withThrowingTaskGroup(of: Void.self) { group in
                for doc in existing.documents {
                    group.addTask { try await doc.reference.delete() }
                }
                try await group.waitForAll()
            }
            try await withThrowingTaskGroup(of: Void.self) { group in
                for (index, entry) in pending.enumerated() {
                    group.addTask {
                        var data: [String: Any] = ["Ref": entry.ref, "Order": index]
                        if let quantity = entry.quantity { data["Quantity"] = quantity }
                        if let unit = entry.unit, !unit.isEmpty { data["Unit"] = unit }
                        try await ingredientSubRef.addDocument(data: data)
                    }
                }
                try await group.waitForAll()
            }

            // Touch the recipe doc last so the listener refetches with the new subcollection.
            // Always include an UpdatedAt server timestamp: if the user only edited
            // ingredients, Name and Instructions are unchanged and Firestore treats the
            // updateData as a no-op that does NOT fire snapshot listeners — meaning the
            // parent recipe listener never re-runs buildRecipes, so the new ingredients
            // never propagate to `userRecipes` and the detail view stays stale until some
            // other real write (e.g. toggling share) forces the listener to fire.
            try await recipeRef.updateData([
                "Name": recipe.title,
                "Instructions": recipe.instructions,
                "UpdatedAt": FieldValue.serverTimestamp()
            ])
            print("Recipe \(recipeId) updated.")
        } catch {
            await report(error, context: "Updating recipe")
        }
    }

    /// Deletes the current user's recipe, including its Ingredients subcollection (Firestore doesn't cascade).
    func deleteRecipe(recipeId: String) async {
        let recipeRef = db.collection("Users").document(currentUserId).collection("Recipes").document(recipeId)
        do {
            let ingredientsSnap = try await recipeRef.collection("Ingredients").getDocuments()
            for doc in ingredientsSnap.documents {
                try await doc.reference.delete()
            }
            try await recipeRef.delete()
            print("Successfully deleted recipe \(recipeId)")
        } catch {
            await report(error, context: "Deleting recipe")
        }
    }

    /// Toggles the IsShared flag on the current user's recipe.
    func toggleShareRecipe(recipeId: String) async {
        let recipeRef = db.collection("Users").document(currentUserId).collection("Recipes").document(recipeId)
        do {
            let snap = try await recipeRef.getDocument()
            let currentlyShared = snap.data()?["IsShared"] as? Bool ?? false
            try await recipeRef.updateData(["IsShared": !currentlyShared])
        } catch {
            await report(error, context: "Toggling recipe sharing")
        }
    }

    /// Copies a shared recipe into the current user's list. The copy is owned by the user and starts unshared.
    /// The original owner's recipe is unaffected.
    func saveSharedRecipeToMyList(_ recipe: Recipe) async {
        await addRecipe(recipe: recipe)
    }

    // MARK: - Pantry

    private func listenToPantry() {
        let ref = db.collection("Users").document(currentUserId).collection("Pantry")
        let registration = ref.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            guard let docs = snapshot?.documents else {
                print("Failed to listen to pantry: \(error?.localizedDescription ?? "unknown error")")
                return
            }
            self.pantryFetchTask?.cancel()
            self.pantryFetchTask = Task { [weak self] in
                guard let self = self else { return }
                let items = await self.fetchIngredients(from: docs, refField: "Ingredient")
                if Task.isCancelled { return }
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.25)) {
                        self.pantryIngredients = items
                    }
                }
            }
        }
        listeners.append(registration)
    }

    func addIngredientToPantry(ref: DocumentReference) async {
        let pantryRef = db.collection("Users").document(currentUserId).collection("Pantry")
        do {
            let existing = try await pantryRef.whereField("Ingredient", isEqualTo: ref).getDocuments()
            if existing.documents.isEmpty {
                try await pantryRef.addDocument(data: [
                    "Ingredient": ref,
                    "CreatedAt": FieldValue.serverTimestamp()
                ])
            }
        } catch {
            await report(error, context: "Adding to pantry")
        }
    }

    func removeIngredientFromPantry(ingredientId: String) async {
        let pantryRef = db.collection("Users").document(currentUserId).collection("Pantry")
        let ingredientRef = db.collection("Ingredients").document(ingredientId)
        do {
            let snap = try await pantryRef.whereField("Ingredient", isEqualTo: ingredientRef).getDocuments()
            for doc in snap.documents {
                try await doc.reference.delete()
            }
        } catch {
            await report(error, context: "Removing from pantry")
        }
    }

    // MARK: - Shopping List

    private func listenToShoppingList() {
        let ref = db.collection("Users").document(currentUserId).collection("ShoppingList")
        let registration = ref.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            guard let docs = snapshot?.documents else {
                print("Failed to listen to shopping list: \(error?.localizedDescription ?? "unknown error")")
                return
            }
            self.shoppingFetchTask?.cancel()
            self.shoppingFetchTask = Task { [weak self] in
                guard let self = self else { return }
                let items = await self.fetchIngredients(from: docs, refField: "Ingredient")
                if Task.isCancelled { return }
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.25)) {
                        self.shoppingListIngredients = items
                    }
                }
            }
        }
        listeners.append(registration)
    }

    func addIngredientToShoppingList(ref: DocumentReference) async {
        let shoppingRef = db.collection("Users").document(currentUserId).collection("ShoppingList")
        do {
            let existing = try await shoppingRef.whereField("Ingredient", isEqualTo: ref).getDocuments()
            if existing.documents.isEmpty {
                try await shoppingRef.addDocument(data: [
                    "Ingredient": ref,
                    "CreatedAt": FieldValue.serverTimestamp()
                ])
            }
        } catch {
            await report(error, context: "Adding to shopping list")
        }
    }

    func removeIngredientFromShoppingList(ingredientId: String) async {
        let shoppingRef = db.collection("Users").document(currentUserId).collection("ShoppingList")
        let ingredientRef = db.collection("Ingredients").document(ingredientId)
        do {
            let snap = try await shoppingRef.whereField("Ingredient", isEqualTo: ingredientRef).getDocuments()
            for doc in snap.documents {
                try await doc.reference.delete()
            }
        } catch {
            await report(error, context: "Removing from shopping list")
        }
    }

    // MARK: - Ingredient helpers

    /// Resolves each ingredient to its (deduped) `/Ingredients` DocumentReference in parallel while
    /// preserving the input order. A plain task group returns results in completion order, which
    /// would scramble the `Order` index written for recipe ingredients; tagging by input index and
    /// re-sorting keeps the persisted order identical to what the user entered.
    private func resolveIngredientsPreservingOrder(
        _ ingredients: [IngredientItem]
    ) async -> [(ref: DocumentReference, quantity: Double?, unit: String?)] {
        let indexed = await withTaskGroup(of: (Int, DocumentReference, Double?, String?)?.self) { group in
            for (index, ingredient) in ingredients.enumerated() {
                group.addTask { [weak self] in
                    guard let ref = await self?.addUniqueIngredient(name: ingredient.name) else { return nil }
                    return (index, ref, ingredient.quantity, ingredient.unit)
                }
            }
            var results: [(Int, DocumentReference, Double?, String?)] = []
            for await entry in group {
                if let entry = entry { results.append(entry) }
            }
            return results
        }
        return indexed
            .sorted { $0.0 < $1.0 }
            .map { (ref: $0.1, quantity: $0.2, unit: $0.3) }
    }

    private func fetchIngredients(from docs: [QueryDocumentSnapshot], refField: String) async -> [IngredientItem] {
        // Sort oldest-first by CreatedAt so newly-added pantry/shopping items land at the bottom.
        // Use `.estimate` so pending-write docs (whose server timestamp hasn't landed yet)
        // sort at their eventual position immediately — otherwise a new item briefly appears
        // at the top with a null timestamp, then jumps to the bottom when the server confirms.
        // Docs missing CreatedAt (legacy) sort to the top.
        let sortedDocs = docs.sorted { a, b in
            let aTime = (a.data(with: .estimate)["CreatedAt"] as? Timestamp)?.dateValue() ?? .distantPast
            let bTime = (b.data(with: .estimate)["CreatedAt"] as? Timestamp)?.dateValue() ?? .distantPast
            return aTime < bTime
        }

        // Preserve the sorted order across parallel fetches by tagging each with its index.
        return await withTaskGroup(of: (Int, IngredientItem?).self) { group in
            for (index, doc) in sortedDocs.enumerated() {
                guard let ref = doc.data()[refField] as? DocumentReference else { continue }
                let quantity = doc.data()["Quantity"] as? Double
                let unit = doc.data()["Unit"] as? String
                group.addTask { [weak self] in
                    let item = await self?.fetchIngredient(from: ref, quantity: quantity, unit: unit)
                    return (index, item)
                }
            }
            var indexed: [(Int, IngredientItem)] = []
            for await (index, item) in group {
                if let item = item { indexed.append((index, item)) }
            }
            return indexed.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }

    private func fetchIngredient(from ref: DocumentReference, quantity: Double? = nil, unit: String? = nil) async -> IngredientItem? {
        do {
            let snap = try await ref.getDocument()
            guard let data = snap.data(),
                  let name = data["Name"] as? String else {
                print("Failed to fetch or parse ingredient from ref: \(ref.path)")
                return nil
            }
            return IngredientItem(id: snap.documentID, name: name, quantity: quantity, unit: unit)
        } catch {
            print("Error fetching ingredient from \(ref.path): \(error.localizedDescription)")
            return nil
        }
    }

    /// Adds an ingredient to /Ingredients only if it doesn't already exist (case-insensitive by name).
    /// Returns the existing or newly-created document reference.
    func addUniqueIngredient(name: String) async -> DocumentReference? {
        let ingredientsRef = db.collection("Ingredients")
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        do {
            let snap = try await ingredientsRef.whereField("NameLower", isEqualTo: lower).getDocuments()
            if let existing = snap.documents.first {
                return existing.reference
            }
            let newRef = ingredientsRef.document()
            try await newRef.setData([
                "Name": trimmed,
                "NameLower": lower
            ])
            return newRef
        } catch {
            await report(error, context: "Saving ingredient")
            return nil
        }
    }

    // MARK: - Domain actions

    func addIngredientToPantry(name: String) async {
        guard let ref = await addUniqueIngredient(name: name) else { return }
        await addIngredientToPantry(ref: ref)
    }

    func addIngredientToShoppingList(name: String) async {
        guard let ref = await addUniqueIngredient(name: name) else { return }
        await addIngredientToShoppingList(ref: ref)
    }

    func moveShoppingItemToPantry(_ ingredient: IngredientItem) async {
        await addIngredientToPantry(name: ingredient.name)
        await removeIngredientFromShoppingList(ingredientId: ingredient.id)
    }

    func addMissingIngredientsToShoppingList(from recipe: Recipe) async {
        let pantryNames = Set(pantryIngredients.map { $0.name.lowercased() })
        let shoppingNames = Set(shoppingListIngredients.map { $0.name.lowercased() })

        // Missing = not already in the pantry and not already on the list, kept in recipe order.
        // We filter here, so the per-item "already on the list?" query in addIngredientToShoppingList
        // isn't needed on this path — one fewer round-trip per ingredient.
        let missing = recipe.ingredients.filter { ingredient in
            let key = ingredient.name.lowercased()
            return !pantryNames.contains(key) && !shoppingNames.contains(key)
        }
        guard !missing.isEmpty else { return }

        // Resolve each to its (deduped) /Ingredients ref in parallel, preserving recipe order.
        let resolved = await resolveIngredientsPreservingOrder(missing)
        guard !resolved.isEmpty else { return }

        // Write every row in a single atomic batch — one round-trip instead of one write per item,
        // which is what caused the delay and the icons updating one-by-one. `CreatedAt` is stamped
        // with strictly increasing client timestamps so the list keeps recipe order: a shared
        // serverTimestamp() across a batch resolves to the same instant for every doc and would
        // sort arbitrarily (the "random order" you saw).
        let shoppingRef = db.collection("Users").document(currentUserId).collection("ShoppingList")
        let batch = db.batch()
        let base = Date()
        for (index, entry) in resolved.enumerated() {
            let doc = shoppingRef.document()
            batch.setData([
                "Ingredient": entry.ref,
                "CreatedAt": Timestamp(date: base.addingTimeInterval(Double(index) * 0.001))
            ], forDocument: doc)
        }

        do {
            try await batch.commit()
        } catch {
            await report(error, context: "Adding to shopping list")
        }
    }

    // MARK: - View helpers (instance methods delegate to pure static helpers below)

    func ingredientsWithStatus(for recipe: Recipe) -> [(ingredient: IngredientItem, isInPantry: Bool, isInShoppingList: Bool)] {
        Self.ingredientsWithStatus(for: recipe, pantry: pantryIngredients, shopping: shoppingListIngredients)
    }

    func hasMissingIngredients(for recipe: Recipe) -> Bool {
        Self.hasMissingIngredients(for: recipe, pantry: pantryIngredients)
    }

    func matchedIngredientCount(for recipe: Recipe) -> Int {
        Self.matchedIngredientCount(for: recipe, pantry: pantryIngredients)
    }

    func recipesSortedByPantryMatch() -> [Recipe] {
        Self.recipesSortedByPantryMatch(recipes: userRecipes, pantry: pantryIngredients)
    }

    /// Which of the current user's recipes contain a given ingredient (case-insensitive by name).
    func recipesContaining(_ ingredient: IngredientItem) -> [Recipe] {
        Self.recipesContaining(ingredient, in: userRecipes)
    }

    // MARK: - Pure helpers (testable — no Firebase dependency)

    static func ingredientsWithStatus(
        for recipe: Recipe,
        pantry: [IngredientItem],
        shopping: [IngredientItem]
    ) -> [(ingredient: IngredientItem, isInPantry: Bool, isInShoppingList: Bool)] {
        let pantryNames = Set(pantry.map { $0.name.lowercased() })
        let shoppingNames = Set(shopping.map { $0.name.lowercased() })
        return recipe.ingredients.map { ingredient in
            let key = ingredient.name.lowercased()
            return (ingredient, pantryNames.contains(key), shoppingNames.contains(key))
        }
    }

    static func hasMissingIngredients(for recipe: Recipe, pantry: [IngredientItem]) -> Bool {
        let pantryNames = Set(pantry.map { $0.name.lowercased() })
        return recipe.ingredients.contains { !pantryNames.contains($0.name.lowercased()) }
    }

    static func matchedIngredientCount(for recipe: Recipe, pantry: [IngredientItem]) -> Int {
        let pantryNames = Set(pantry.map { $0.name.lowercased() })
        return recipe.ingredients.filter { pantryNames.contains($0.name.lowercased()) }.count
    }

    static func recipesSortedByPantryMatch(recipes: [Recipe], pantry: [IngredientItem]) -> [Recipe] {
        recipes.sorted { matchedIngredientCount(for: $0, pantry: pantry) > matchedIngredientCount(for: $1, pantry: pantry) }
    }

    static func recipesContaining(_ ingredient: IngredientItem, in recipes: [Recipe]) -> [Recipe] {
        let key = ingredient.name.lowercased()
        return recipes.filter { recipe in
            recipe.ingredients.contains { $0.name.lowercased() == key }
        }
    }

    func togglePantry(ingredient: IngredientItem) async {
        if let existing = pantryIngredients.first(where: { $0.name.lowercased() == ingredient.name.lowercased() }) {
            await removeIngredientFromPantry(ingredientId: existing.id)
        } else {
            await addIngredientToPantry(name: ingredient.name)
        }
    }

    func toggleShoppingList(ingredient: IngredientItem) async {
        if let existing = shoppingListIngredients.first(where: { $0.name.lowercased() == ingredient.name.lowercased() }) {
            await removeIngredientFromShoppingList(ingredientId: existing.id)
        } else {
            await addIngredientToShoppingList(name: ingredient.name)
        }
    }
}
