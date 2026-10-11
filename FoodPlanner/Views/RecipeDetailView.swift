import SwiftUI
import UIKit

struct RecipeDetailView: View {
    // Held locally and refreshed via .onReceive whenever DataManager republishes (plan 4.1: remove this once
    // verified on a device that a computed lookup alone never goes stale after an edit).
    private let recipeId: String
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @State private var recipe: Recipe
    /// The servings the page is currently scaled to (nil: as written).
    @State private var displayedServings: Int?
    @State private var showDeleteConfirmation = false

    // Inline editing. Rather than pushing a separate edit page (which caused a jarring
    // reload/reshuffle on pop-back once Firestore echoed the write), editing happens in
    // place: `isEditing` flips the detail view into an editable form backed by `editVM`.
    @StateObject private var editVM = RecipeFormViewModel()
    @State private var isEditing = false
    @State private var showAddToPlan = false

    init(recipe: Recipe) {
        self.recipeId = recipe.id
        self._recipe = State(initialValue: recipe)
    }

    private var isOwnedByCurrentUser: Bool {
        recipe.ownerId == dataManager.currentUserId
    }

    private func syncFromDataManager() {
        if let updated = dataManager.userRecipes.first(where: { $0.id == recipeId })
            ?? dataManager.sharedRecipes.first(where: { $0.id == recipeId })
        {
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
            let updated = dataManager.sharedRecipes.first(where: { $0.id == recipeId })
        {
            recipe = updated
        }
    }

    var body: some View {
        Group {
            if isEditing {
                RecipeFormView(
                    viewModel: editVM, idPrefix: "detail.edit", knownNames: dataManager.knownIngredientNames)
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
        .coversRotation()
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
                        .accessibilityIdentifier("detail.edit.save")
                        .fontWeight(.semibold)
                        .disabled(!editVM.isFormValid())
                }
            } else {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddToPlan = true
                    } label: {
                        Image(systemName: "calendar.badge.plus")
                    }
                    .accessibilityLabel("Add to plan")
                    .accessibilityIdentifier("detail.addToPlan")
                }
                if isOwnedByCurrentUser {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ownerMenu
                    }
                }
            }
        }
        .sheet(isPresented: $showAddToPlan) {
            AddToPlanSheet(recipe: recipe)
        }
        .confirmationDialog(
            "Delete “\(recipe.title)”?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Recipe", role: .destructive) {
                Task { await dataManager.deleteRecipe(recipeId: recipe.id) }
                dismiss()
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
                    SharedRecipeBanner(ownerName: recipe.ownerName)
                }

                RecipeIngredientsSection(recipe: recipe, displayedServings: $displayedServings)
                RecipeInstructionsSection(instructions: recipe.instructions)
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
                        SharedRecipeBanner(ownerName: recipe.ownerName)
                    }
                    RecipeIngredientsSection(recipe: recipe, displayedServings: $displayedServings)
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

    // MARK: - Edit actions

    private func beginEdit() {
        editVM.load(from: recipe)
        isEditing = true
    }

    private func cancelEdit() {
        isEditing = false
    }

    private func saveEdit() {
        // Commit any half-typed ingredient before building.
        editVM.commitPendingIngredient()
        guard let built = editVM.buildRecipe() else { return }
        // Optimistically apply to local state so the view reflects the edit instantly. Keying the
        // ingredient list by name (see RecipeIngredientsSection) means the later Firestore republish
        // matches these rows by identity and doesn't reshuffle. Preserve id/ownerId/isShared.
        recipe.title = built.title
        recipe.ingredients = built.ingredients
        recipe.instructions = built.instructions
        recipe.servings = built.servings
        displayedServings = nil
        Task { await dataManager.updateRecipe(recipeId: recipeId, recipe: built) }
        isEditing = false
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
                Task { await dataManager.setShared(recipeId: recipe.id, isShared: !recipe.isShared) }
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

    @ViewBuilder
    private var actionsSection: some View {
        if !isOwnedByCurrentUser {
            SaveSharedRecipeButton(recipe: recipe)
        }
    }
}
