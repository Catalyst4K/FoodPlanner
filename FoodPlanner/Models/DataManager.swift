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

    // MARK: - Pantry and shopping list
    //
    // Both are keyed collections: the document ID is `IngredientKey.documentID(for: name)`, so adding the
    // same ingredient twice (or from two devices) writes the same document, and removing one is a plain delete.

    private var pantryRef: CollectionReference {
        db.collection("Users").document(currentUserId).collection("Pantry")
    }

    private var shoppingRef: CollectionReference {
        db.collection("Users").document(currentUserId).collection("ShoppingList")
    }

    private func listenToPantry() {
        let registration = pantryRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                self.report(error, context: "Pantry")
                return
            }
            guard let docs = snapshot?.documents else { return }
            let items = Self.listItems(from: docs)
            withAnimation(.easeOut(duration: 0.25)) {
                self.pantryIngredients = items
            }
        }
        listeners.append(registration)
    }

    private func listenToShoppingList() {
        let registration = shoppingRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                self.report(error, context: "Shopping list")
                return
            }
            guard let docs = snapshot?.documents else { return }
            let items = Self.listItems(from: docs)
            withAnimation(.easeOut(duration: 0.25)) {
                self.shoppingListIngredients = items
            }
        }
        listeners.append(registration)
    }

    /// Parses pantry or shopping-list documents synchronously, oldest first so new items land at the bottom.
    /// `.estimate` places pending-write docs (server timestamp not yet resolved) at their eventual position
    /// instead of briefly at the top. Documents that don't match schema v2 are skipped and logged.
    private static func listItems(from docs: [QueryDocumentSnapshot]) -> [IngredientItem] {
        func createdAt(_ doc: QueryDocumentSnapshot) -> Date {
            (doc.data(with: .estimate)["CreatedAt"] as? Timestamp)?.dateValue() ?? .distantPast
        }
        return docs.sorted { createdAt($0) < createdAt($1) }.compactMap { doc in
            let item = FirestoreMapping.listItem(from: doc.data(with: .estimate), id: doc.documentID)
            if item == nil { print("Skipping list item that doesn't match schema v2: \(doc.reference.path)") }
            return item
        }
    }

    /// Adds an ingredient to the pantry. Idempotent: skipped if it is already there, so `CreatedAt` isn't reset.
    @discardableResult
    func addToPantry(name: String) async -> Bool {
        await addToList(pantryRef, existing: pantryIngredients, name: name, context: "Adding to pantry")
    }

    @discardableResult
    func addToShoppingList(name: String) async -> Bool {
        await addToList(shoppingRef, existing: shoppingListIngredients, name: name, context: "Adding to shopping list")
    }

    @discardableResult
    func removeFromPantry(id: String) async -> Bool {
        await remove(id: id, from: pantryRef, context: "Removing from pantry")
    }

    @discardableResult
    func removeFromShoppingList(id: String) async -> Bool {
        await remove(id: id, from: shoppingRef, context: "Removing from shopping list")
    }

    private func addToList(
        _ collection: CollectionReference, existing: [IngredientItem], name: String, context: String
    ) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let id = IngredientKey.documentID(for: trimmed)
        if existing.contains(where: { $0.id == id }) { return true }
        do {
            try await collection.document(id).setData(["Name": trimmed, "CreatedAt": FieldValue.serverTimestamp()])
            return true
        } catch {
            report(error, context: context)
            return false
        }
    }

    private func remove(id: String, from collection: CollectionReference, context: String) async -> Bool {
        do {
            try await collection.document(id).delete()
            return true
        } catch {
            report(error, context: context)
            return false
        }
    }

    /// Moves a shopping-list item to the pantry in one atomic batch (set the pantry doc, delete the list doc).
    @discardableResult
    func moveShoppingItemToPantry(_ ingredient: IngredientItem) async -> Bool {
        let trimmed = ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let pantryID = IngredientKey.documentID(for: trimmed)
        let batch = db.batch()
        if !pantryIngredients.contains(where: { $0.id == pantryID }) {
            batch.setData(
                ["Name": trimmed, "CreatedAt": FieldValue.serverTimestamp()], forDocument: pantryRef.document(pantryID))
        }
        batch.deleteDocument(shoppingRef.document(ingredient.id))
        do {
            try await batch.commit()
            return true
        } catch {
            report(error, context: "Moving to pantry")
            return false
        }
    }

    /// Adds the recipe's ingredients that are neither in the pantry nor already on the list, in recipe order,
    /// in a single atomic batch. `CreatedAt` uses strictly increasing client timestamps: a shared
    /// `serverTimestamp()` across a batch resolves to one instant for every doc and would sort arbitrarily.
    @discardableResult
    func addMissingIngredientsToShoppingList(from recipe: Recipe) async -> Bool {
        let pantryKeys = Set(pantryIngredients.map { IngredientKey.documentID(for: $0.name) })
        let shoppingKeys = Set(shoppingListIngredients.map { IngredientKey.documentID(for: $0.name) })

        var seen = Set<String>()
        let missing = recipe.ingredients.compactMap { ingredient -> (id: String, name: String)? in
            let name = ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let id = IngredientKey.documentID(for: name)
            guard !name.isEmpty, !pantryKeys.contains(id), !shoppingKeys.contains(id), seen.insert(id).inserted
            else { return nil }
            return (id, name)
        }
        guard !missing.isEmpty else { return true }

        let batch = db.batch()
        let base = Date()
        for (index, entry) in missing.enumerated() {
            batch.setData(
                [
                    "Name": entry.name,
                    "CreatedAt": Timestamp(date: base.addingTimeInterval(Double(index) * 0.001)),
                ], forDocument: shoppingRef.document(entry.id))
        }
        do {
            try await batch.commit()
            return true
        } catch {
            report(error, context: "Adding to shopping list")
            return false
        }
    }

    // MARK: - Account deletion

    /// Deletes everything the current user owns: recipes (shared ones too), pantry, shopping list, then the
    /// user document. Idempotent, so it is safe to retry after a partial failure. The caller re-authenticates
    /// first and deletes the Auth account afterwards.
    @discardableResult
    func deleteAllUserData() async -> Bool {
        do {
            for collection in [userRecipesRef, pantryRef, shoppingRef] {
                try await deleteAllDocuments(in: collection)
            }
            try await db.collection("Users").document(currentUserId).delete()
            return true
        } catch {
            report(error, context: "Deleting account data")
            return false
        }
    }

    /// Deletes a collection's documents in batches (Firestore allows at most 500 writes per batch).
    private func deleteAllDocuments(in collection: CollectionReference) async throws {
        while true {
            let snapshot = try await collection.limit(to: 450).getDocuments()
            if snapshot.documents.isEmpty { return }
            let batch = db.batch()
            snapshot.documents.forEach { batch.deleteDocument($0.reference) }
            try await batch.commit()
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

    nonisolated static func recipesContaining(_ ingredient: IngredientItem, in recipes: [Recipe]) -> [Recipe] {
        let key = IngredientKey.normalized(ingredient.name)
        return recipes.filter { recipe in
            recipe.ingredients.contains { IngredientKey.normalized($0.name) == key }
        }
    }

    @discardableResult
    func togglePantry(ingredient: IngredientItem) async -> Bool {
        let key = IngredientKey.normalized(ingredient.name)
        if let existing = pantryIngredients.first(where: { IngredientKey.normalized($0.name) == key }) {
            return await removeFromPantry(id: existing.id)
        }
        return await addToPantry(name: ingredient.name)
    }

    @discardableResult
    func toggleShoppingList(ingredient: IngredientItem) async -> Bool {
        let key = IngredientKey.normalized(ingredient.name)
        if let existing = shoppingListIngredients.first(where: { IngredientKey.normalized($0.name) == key }) {
            return await removeFromShoppingList(id: existing.id)
        }
        return await addToShoppingList(name: ingredient.name)
    }
}
