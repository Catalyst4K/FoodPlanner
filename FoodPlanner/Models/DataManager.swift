import SwiftUI
import Firebase
import FirebaseFirestore

@MainActor
class DataManager: ObservableObject {
    @Published var userRecipes: [Recipe] = []
    @Published var sharedRecipes: [Recipe] = []
    @Published var pantryIngredients: [IngredientItem] = []
    @Published var shoppingListIngredients: [IngredientItem] = []
    @Published var errorMessage: String?

    let currentUserId: String
    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []

    // Pantry and shopping-list fetch tasks (removed in plan task 1.5): when a snapshot arrives, the
    // previous fetch is cancelled so a slow older snapshot can't overwrite a newer one.
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

    private func report(_ error: Error, context: String) {
        let message = "\(context): \(error.localizedDescription)"
        print(message)
        errorMessage = message
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Recipes (owned by current user)

    private func listenToUserRecipes() {
        let ref = db.collection("Users").document(currentUserId).collection("Recipes")
        let registration = ref.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                self.report(error, context: "Recipes")
                return
            }
            guard let docs = snapshot?.documents else { return }
            let recipes = Self.recipes(from: docs)
            withAnimation(.easeOut(duration: 0.25)) {
                self.userRecipes = recipes
            }
        }
        listeners.append(registration)
    }

    private func listenToSharedRecipes() {
        // Needs a composite collection-group index (IsShared ASC, CreatedAt DESC): firebase/firestore.indexes.json.
        // If it's missing, Firestore's error includes a console link to create it.
        let query = db.collectionGroup("Recipes")
            .whereField("IsShared", isEqualTo: true)
            .order(by: "CreatedAt", descending: true)
            .limit(to: 200)
        let registration = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                self.report(error, context: "Shared recipes")
                return
            }
            guard let docs = snapshot?.documents else { return }
            let recipes = Self.recipes(from: docs)
            withAnimation(.easeOut(duration: 0.25)) {
                // Exclude the current user's own recipes; they're already in userRecipes.
                self.sharedRecipes = recipes.filter { $0.ownerId != self.currentUserId }
            }
        }
        listeners.append(registration)
    }

    /// Parses recipe documents synchronously, newest first. Documents that don't match schema v2
    /// (for example old v1 recipes whose ingredients lived in a subcollection) are skipped and logged.
    private static func recipes(from docs: [QueryDocumentSnapshot]) -> [Recipe] {
        // `.estimate` places freshly-written docs, whose server timestamp hasn't resolved yet, at their
        // eventual position (no visible jump when the server confirms). Docs without CreatedAt go last.
        func createdAt(_ doc: QueryDocumentSnapshot) -> Date {
            (doc.data(with: .estimate)["CreatedAt"] as? Timestamp)?.dateValue() ?? .distantPast
        }
        return docs.sorted { createdAt($0) > createdAt($1) }.compactMap { doc in
            let fallbackOwnerId = doc.reference.parent.parent?.documentID ?? ""
            let recipe = FirestoreMapping.recipe(
                from: doc.data(with: .estimate), id: doc.documentID, fallbackOwnerId: fallbackOwnerId)
            if recipe == nil { print("Skipping recipe that doesn't match schema v2: \(doc.reference.path)") }
            return recipe
        }
    }

    private var userRecipesRef: CollectionReference {
        db.collection("Users").document(currentUserId).collection("Recipes")
    }

    /// Adds a recipe owned by the current user, unshared. One atomic write.
    /// `sourcePath` records where a copy came from (`Users/{owner}/Recipes/{id}`).
    @discardableResult
    func addRecipe(recipe: Recipe, sourcePath: String? = nil) async -> Bool {
        var fields = FirestoreMapping.recipeFields(recipe)
        fields["OwnerId"] = currentUserId
        fields["IsShared"] = false
        fields["CreatedAt"] = FieldValue.serverTimestamp()
        fields["UpdatedAt"] = FieldValue.serverTimestamp()
        if let sourcePath { fields["SourceRecipePath"] = sourcePath }
        do {
            try await userRecipesRef.document().setData(fields)
            return true
        } catch {
            report(error, context: "Adding recipe")
            return false
        }
    }

    /// Updates a recipe's title, instructions and ingredients in one atomic write. `UpdatedAt` always
    /// changes, so the listener fires even if only ingredients differ.
    @discardableResult
    func updateRecipe(recipeId: String, recipe: Recipe) async -> Bool {
        var fields = FirestoreMapping.recipeFields(recipe)
        fields["UpdatedAt"] = FieldValue.serverTimestamp()
        do {
            try await userRecipesRef.document(recipeId).updateData(fields)
            return true
        } catch {
            report(error, context: "Updating recipe")
            return false
        }
    }

    @discardableResult
    func deleteRecipe(recipeId: String) async -> Bool {
        do {
            try await userRecipesRef.document(recipeId).delete()
            return true
        } catch {
            report(error, context: "Deleting recipe")
            return false
        }
    }

    /// Sets whether the current user's recipe is shared with other signed-in users.
    @discardableResult
    func setShared(recipeId: String, isShared: Bool) async -> Bool {
        do {
            try await userRecipesRef.document(recipeId).updateData(["IsShared": isShared])
            return true
        } catch {
            report(error, context: "Updating recipe sharing")
            return false
        }
    }

    /// Copies a shared recipe into the current user's list. The copy is owned by the user and starts
    /// unshared; the original is unaffected.
    @discardableResult
    func saveSharedRecipeToMyList(_ recipe: Recipe) async -> Bool {
        await addRecipe(recipe: recipe, sourcePath: "Users/\(recipe.ownerId)/Recipes/\(recipe.id)")
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
                withAnimation(.easeOut(duration: 0.25)) {
                    self.pantryIngredients = items
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
                    "CreatedAt": FieldValue.serverTimestamp(),
                ])
            }
        } catch {
            report(error, context: "Adding to pantry")
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
            report(error, context: "Removing from pantry")
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
                withAnimation(.easeOut(duration: 0.25)) {
                    self.shoppingListIngredients = items
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
                    "CreatedAt": FieldValue.serverTimestamp(),
                ])
            }
        } catch {
            report(error, context: "Adding to shopping list")
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
            report(error, context: "Removing from shopping list")
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
        return
            indexed
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

    private func fetchIngredient(from ref: DocumentReference, quantity: Double? = nil, unit: String? = nil) async
        -> IngredientItem?
    {
        do {
            let snap = try await ref.getDocument()
            guard let data = snap.data(),
                let name = data["Name"] as? String
            else {
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
                "NameLower": lower,
            ])
            return newRef
        } catch {
            report(error, context: "Saving ingredient")
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
        let pantryNames = Set(pantryIngredients.map { IngredientKey.normalized($0.name) })
        let shoppingNames = Set(shoppingListIngredients.map { IngredientKey.normalized($0.name) })

        // Missing = not already in the pantry and not already on the list, kept in recipe order.
        // We filter here, so the per-item "already on the list?" query in addIngredientToShoppingList
        // isn't needed on this path — one fewer round-trip per ingredient.
        let missing = recipe.ingredients.filter { ingredient in
            let key = IngredientKey.normalized(ingredient.name)
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
            batch.setData(
                [
                    "Ingredient": entry.ref,
                    "CreatedAt": Timestamp(date: base.addingTimeInterval(Double(index) * 0.001)),
                ], forDocument: doc)
        }

        do {
            try await batch.commit()
        } catch {
            report(error, context: "Adding to shopping list")
        }
    }

    // MARK: - View helpers (instance methods delegate to pure static helpers below)

    func ingredientsWithStatus(for recipe: Recipe) -> [(
        ingredient: IngredientItem, isInPantry: Bool, isInShoppingList: Bool
    )] {
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

    nonisolated static func ingredientsWithStatus(
        for recipe: Recipe,
        pantry: [IngredientItem],
        shopping: [IngredientItem]
    ) -> [(ingredient: IngredientItem, isInPantry: Bool, isInShoppingList: Bool)] {
        let pantryNames = Set(pantry.map { IngredientKey.normalized($0.name) })
        let shoppingNames = Set(shopping.map { IngredientKey.normalized($0.name) })
        return recipe.ingredients.map { ingredient in
            let key = IngredientKey.normalized(ingredient.name)
            return (ingredient, pantryNames.contains(key), shoppingNames.contains(key))
        }
    }

    nonisolated static func hasMissingIngredients(for recipe: Recipe, pantry: [IngredientItem]) -> Bool {
        let pantryNames = Set(pantry.map { IngredientKey.normalized($0.name) })
        return recipe.ingredients.contains { !pantryNames.contains(IngredientKey.normalized($0.name)) }
    }

    nonisolated static func matchedIngredientCount(for recipe: Recipe, pantry: [IngredientItem]) -> Int {
        let pantryNames = Set(pantry.map { IngredientKey.normalized($0.name) })
        return recipe.ingredients.filter { pantryNames.contains(IngredientKey.normalized($0.name)) }.count
    }

    nonisolated static func recipesSortedByPantryMatch(recipes: [Recipe], pantry: [IngredientItem]) -> [Recipe] {
        recipes.sorted {
            matchedIngredientCount(for: $0, pantry: pantry) > matchedIngredientCount(for: $1, pantry: pantry)
        }
    }

    nonisolated static func recipesContaining(_ ingredient: IngredientItem, in recipes: [Recipe]) -> [Recipe] {
        let key = IngredientKey.normalized(ingredient.name)
        return recipes.filter { recipe in
            recipe.ingredients.contains { IngredientKey.normalized($0.name) == key }
        }
    }

    func togglePantry(ingredient: IngredientItem) async {
        if let existing = pantryIngredients.first(where: {
            IngredientKey.normalized($0.name) == IngredientKey.normalized(ingredient.name)
        }) {
            await removeIngredientFromPantry(ingredientId: existing.id)
        } else {
            await addIngredientToPantry(name: ingredient.name)
        }
    }

    func toggleShoppingList(ingredient: IngredientItem) async {
        if let existing = shoppingListIngredients.first(where: {
            IngredientKey.normalized($0.name) == IngredientKey.normalized(ingredient.name)
        }) {
            await removeIngredientFromShoppingList(ingredientId: existing.id)
        } else {
            await addIngredientToShoppingList(name: ingredient.name)
        }
    }
}
