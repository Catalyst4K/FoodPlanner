import SwiftUI
import UIKit

struct RecipeDetailView: View {
    // Held locally and refreshed via .onReceive whenever DataManager republishes.
    // We can't rely on a computed lookup + @EnvironmentObject re-render alone:
    // under NavigationView, a pushed detail view often doesn't re-evaluate its
    // body when observed state changes while a child (edit sheet) is on top —
    // so on pop-back the stale render is what the user sees. Explicitly syncing
    // via onReceive on the @Published publishers guarantees we pick up edits.
    private let recipeId: String
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode
    @State private var recipe: Recipe
    @State private var didPressAddAll = false
    @State private var didPressSave = false
    @State private var showDeleteConfirmation = false
    @State private var overlayOpacity: Double = 0

    // Inline editing. Rather than pushing a separate edit page (which caused a jarring
    // reload/reshuffle on pop-back once Firestore echoed the write), editing happens in
    // place: `isEditing` flips the detail view into an editable form backed by `editVM`.
    @StateObject private var editVM = RecipeListViewModel()
    @State private var isEditing = false
    @State private var newIngredientText = ""
    @FocusState private var isAddIngredientFocused: Bool

    init(recipe: Recipe) {
        self.recipeId = recipe.id
        self._recipe = State(initialValue: recipe)
    }

    private var isOwnedByCurrentUser: Bool {
        recipe.ownerId == dataManager.currentUserId
    }

    private func syncFromDataManager() {
        if let updated = dataManager.userRecipes.first(where: { $0.id == recipeId })
            ?? dataManager.sharedRecipes.first(where: { $0.id == recipeId }) {
            recipe = updated
        }
    }

    /// `@Published`'s publisher fires in `willSet`, which runs BEFORE the property's storage
    /// is actually updated. That means reading `dataManager.userRecipes` inside an onReceive
    /// closure returns the OLD array (the property hasn't been overwritten yet). So we accept
    /// the fresh array as the closure argument and search it directly instead.
    private func syncFrom(recipes newRecipes: [Recipe], fallbackToShared: Bool) {
        if let updated = newRecipes.first(where: { $0.id == recipeId }) {
            recipe = updated
        } else if fallbackToShared,
                  let updated = dataManager.sharedRecipes.first(where: { $0.id == recipeId }) {
            recipe = updated
        }
    }

    /// A displayable ingredient row with a stable identity for `ForEach`. `id` is the lowercased
    /// name: the same ingredient is optimistically shown with the user-typed casing but comes back
    /// from the listener with the canonical casing stored in `/Ingredients`. Keying by the raw name
    /// would make those rows change identity on republish and animate ("jump"); lowercasing keeps
    /// them stable. Names are unique within a recipe (deduped case-insensitively).
    private struct IngredientRow: Identifiable {
        let id: String
        let ingredient: IngredientItem
        let isInPantry: Bool
        let isInShoppingList: Bool
    }

    private var ingredientRows: [IngredientRow] {
        dataManager.ingredientsWithStatus(for: recipe).map { status in
            IngredientRow(
                id: status.ingredient.name.lowercased(),
                ingredient: status.ingredient,
                isInPantry: status.isInPantry,
                isInShoppingList: status.isInShoppingList
            )
        }
    }

    private var shouldShowAddAllButton: Bool {
        dataManager.hasMissingIngredients(for: recipe)
    }

    var body: some View {
        Group {
            if isEditing {
                editForm
            } else {
                GeometryReader { proxy in
                    if proxy.size.width > proxy.size.height {
                        landscapeLayout
                    } else {
                        portraitLayout
                    }
                }
            }
        }
        // Solid background so any exposed edges during rotation blend in instead of showing black.
        .background(Color(.systemBackground).ignoresSafeArea())
        // Full-screen cover that hides the rotation animation. Appears INSTANTLY on rotation
        // (no fade-in — otherwise the UIKit rotation animation would already be underway),
        // then fades out once rotation has completed, revealing the newly-laid-out orientation.
        .overlay {
            Color(.systemBackground)
                .ignoresSafeArea()
                // Extra oversize keeps corners covered while UIKit rotates the frame.
                .frame(width: 3000, height: 3000)
                .opacity(overlayOpacity)
                .allowsHitTesting(overlayOpacity > 0.01)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            // Only mask real orientation changes (portrait ↔ landscape). Ignore face-up / face-down.
            let orientation = UIDevice.current.orientation
            guard orientation.isPortrait || orientation.isLandscape else { return }

            overlayOpacity = 1  // Instant cover — critically no animation here.
            // Wait past UIKit's rotation animation (~0.3–0.4s) before fading the cover out.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 0.35)) {
                    overlayOpacity = 0
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Recipe" : recipe.title)
        .navigationBarTitleDisplayMode(.inline)
        // While editing, hide the back button so the user commits via Save/Cancel rather than
        // swiping away mid-edit and silently discarding changes.
        .navigationBarBackButtonHidden(isEditing)
        .toolbar {
            if isEditing {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: cancelEdit)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save", action: saveEdit)
                        .fontWeight(.semibold)
                        .disabled(!editVM.isFormValid())
                }
            } else if isOwnedByCurrentUser {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ownerMenu
                }
            }
        }
        .confirmationDialog(
            "Delete “\(recipe.title)”?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Recipe", role: .destructive) {
                Task { await dataManager.deleteRecipe(recipeId: recipe.id) }
                presentationMode.wrappedValue.dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
        .onAppear {
            AppDelegate.setAllowedOrientations([.portrait, .landscapeLeft, .landscapeRight])
            syncFromDataManager()
        }
        .onDisappear {
            AppDelegate.setAllowedOrientations(.portrait)
        }
        .onReceive(dataManager.$userRecipes) { newRecipes in
            syncFrom(recipes: newRecipes, fallbackToShared: true)
        }
        .onReceive(dataManager.$sharedRecipes) { newRecipes in
            syncFrom(recipes: newRecipes, fallbackToShared: false)
        }
    }

    // MARK: - Layouts

    /// Vertical: title / banner / ingredients / instructions / actions in one scrolling column.
    private var portraitLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                titleRow

                if !isOwnedByCurrentUser {
                    sharedBanner
                }

                ingredientsSection
                instructionsSection
                actionsSection
            }
            .padding()
        }
    }

    /// Landscape: ingredients pinned on the left, instructions on the right — both scroll independently.
    /// Optimised for reading while cooking with a device propped up horizontally.
    private var landscapeLayout: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left column — ingredients
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !isOwnedByCurrentUser {
                        sharedBanner
                    }
                    ingredientsSection
                    actionsSection
                }
                .padding()
            }
            .frame(maxWidth: .infinity)

            Divider()

            // Right column — instructions
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Instructions")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(recipe.instructions)
                        .font(.body)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Edit form

    /// In-place editable form shown when `isEditing`. Mirrors AddRecipeView's fields but lives on
    /// the detail view so there's no page push/pop — the user stays on the same screen.
    private var editForm: some View {
        ScrollView {
            VStack(spacing: 20) {
                editTitleField
                editIngredientsSection
                editInstructionsSection
            }
            .padding(.bottom, 100)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var editTitleField: some View {
        TextField("Recipe Title", text: $editVM.title)
            .font(.title)
            .fontWeight(.bold)
            .padding(.top, 40)
            .multilineTextAlignment(.center)
            .textFieldStyle(.plain)
            .padding(.horizontal)
            .overlay(Divider().background(Color.gray), alignment: .bottom)
            .padding(.horizontal)
    }

    private var editIngredientsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Ingredients")
                .font(.title2)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 4)

            ForEach(editVM.ingredients) { ingredient in
                editIngredientRow(ingredient)
                    .transition(.opacity)
            }

            addIngredientRow
            tapToAddSpacer
        }
    }

    // Fills the empty area under the ingredient list. Tapping it toggles the add field: focuses it
    // when idle, or dismisses the keyboard when typing (losing focus commits any in-progress text).
    private var tapToAddSpacer: some View {
        Color.clear
            .contentShape(Rectangle())
            .frame(minHeight: 120)
            .onTapGesture {
                isAddIngredientFocused.toggle()
            }
    }

    private func editIngredientRow(_ ingredient: IngredientItem) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(ingredient.name)
                    .padding(.vertical, 10)
                    .padding(.horizontal)
                    .foregroundColor(.primary)

                Spacer()

                Button {
                    withAnimation(.easeOut(duration: 0.25)) {
                        editVM.removeIngredient(id: ingredient.id)
                    }
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .padding(5)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            Divider()
        }
    }

    private var addIngredientRow: some View {
        HStack {
            Button {
                commitIngredient()
                isAddIngredientFocused = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.gray)
                    .padding(.leading)
            }
            .buttonStyle(.plain)

            TextField("Add ingredient", text: $newIngredientText)
                .focused($isAddIngredientFocused)
                .padding(.vertical, 10)
                .padding(.horizontal, 4)
                .submitLabel(.return)
                .onSubmit(commitIngredient)
        }
        .padding(.horizontal)
        .onChange(of: isAddIngredientFocused) { was, _ in
            if was { commitIngredient() }
        }
    }

    private var editInstructionsSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Instructions")
                .font(.title2)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.top, 20)

            TextEditor(text: $editVM.instructions)
                .frame(minHeight: 150)
                .padding(10)
                .background(Color.white)
                .cornerRadius(20)
                .font(.body)
                .padding(.horizontal)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.gray, lineWidth: 0.5)
                        .padding(10)
                }
        }
    }

    // MARK: - Edit actions

    private func beginEdit() {
        editVM.load(from: recipe)
        newIngredientText = ""
        isEditing = true
    }

    private func cancelEdit() {
        newIngredientText = ""
        isAddIngredientFocused = false
        isEditing = false
    }

    private func saveEdit() {
        // Commit any half-typed ingredient before building.
        commitIngredient()
        guard let built = editVM.buildRecipe() else { return }
        // Optimistically apply to local state so the view reflects the edit instantly. Keying the
        // ingredient list by name (see ingredientsSection) means the later Firestore republish
        // matches these rows by identity and doesn't reshuffle. Preserve id/ownerId/isShared.
        recipe.title = built.title
        recipe.ingredients = built.ingredients
        recipe.instructions = built.instructions
        Task { await dataManager.updateRecipe(recipeId: recipeId, recipe: built) }
        isAddIngredientFocused = false
        isEditing = false
    }

    private func commitIngredient() {
        let trimmed = newIngredientText.trimmingCharacters(in: .whitespaces)
        newIngredientText = ""
        guard !trimmed.isEmpty else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            editVM.addIngredient(name: trimmed)
        }
    }

    // MARK: - Menu

    private var ownerMenu: some View {
        Menu {
            Button {
                beginEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                Task { await dataManager.toggleShareRecipe(recipeId: recipe.id) }
            } label: {
                Label(
                    recipe.isShared ? "Unshare" : "Share",
                    systemImage: recipe.isShared ? "person.2.fill" : "person.2"
                )
            }

            Divider()

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete Recipe", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Recipe options")
    }

    // MARK: - Sections

    private var titleRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(recipe.title)
                .font(.largeTitle)
                .fontWeight(.bold)

            if isOwnedByCurrentUser && recipe.isShared {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
                    .accessibilityLabel("Shared with other users")
            }
        }
        .padding(.top, 20)
    }

    private var sharedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.2.fill")
                .foregroundColor(.blue)
            Text("Shared by another user")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("Ingredients")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top, 10)

                Spacer()

                if shouldShowAddAllButton {
                    Button {
                        Task { await dataManager.addMissingIngredientsToShoppingList(from: recipe) }
                        withAnimation(.easeInOut(duration: 0.2)) { didPressAddAll = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.easeInOut(duration: 0.2)) { didPressAddAll = false }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "cart.fill")
                            Text("Add All").font(.body)
                        }
                        .foregroundColor(.blue)
                        .padding(5)
                        .opacity(didPressAddAll ? 0.4 : 1.0)
                    }
                }
            }

            ForEach(ingredientRows) { status in
                HStack {
                    Button {
                        Task { await dataManager.togglePantry(ingredient: status.ingredient) }
                    } label: {
                        Image(systemName: status.isInPantry ? "refrigerator.fill" : "refrigerator")
                            .foregroundColor(status.isInPantry ? .green : .gray)
                    }
                    .buttonStyle(.plain)

                    Text(status.ingredient.name)
                        .font(.body)
                        .padding(.bottom, 2)

                    Spacer()

                    if !status.isInPantry {
                        Button {
                            Task { await dataManager.toggleShoppingList(ingredient: status.ingredient) }
                        } label: {
                            Image(systemName: status.isInShoppingList ? "cart.fill" : "cart")
                                .foregroundColor(status.isInShoppingList ? .blue : .gray)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Divider().padding(.vertical, 10)

            Text("Instructions")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 10)

            Text(recipe.instructions)
                .font(.body)
                .padding(.top, 10)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var actionsSection: some View {
        if !isOwnedByCurrentUser {
            Button {
                Task { await dataManager.saveSharedRecipeToMyList(recipe) }
                withAnimation(.easeInOut(duration: 0.2)) { didPressSave = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    presentationMode.wrappedValue.dismiss()
                }
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text(didPressSave ? "Saved!" : "Save to My Recipes")
                }
                .foregroundColor(.white)
                .fontWeight(.bold)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.top, 20)
            .disabled(didPressSave)
        }
    }
}
