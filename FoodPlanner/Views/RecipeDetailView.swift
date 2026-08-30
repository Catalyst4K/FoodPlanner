import SwiftUI
import UIKit

struct RecipeDetailView: View {
    var recipe: Recipe
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode
    @State private var didPressAddAll = false
    @State private var didPressSave = false
    @State private var showEdit = false
    @State private var showDeleteConfirmation = false
    @State private var overlayOpacity: Double = 0

    private var isOwnedByCurrentUser: Bool {
        recipe.ownerId == dataManager.currentUserId
    }

    private var ingredientsWithStatus: [(ingredient: IngredientItem, isInPantry: Bool, isInShoppingList: Bool)] {
        dataManager.ingredientsWithStatus(for: recipe)
    }

    private var shouldShowAddAllButton: Bool {
        dataManager.hasMissingIngredients(for: recipe)
    }

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width > proxy.size.height {
                landscapeLayout
            } else {
                portraitLayout
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
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isOwnedByCurrentUser {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ownerMenu
                }
            }
        }
        .navigationDestination(isPresented: $showEdit) {
            AddRecipeView(
                viewModel: RecipeListViewModel(editing: recipe),
                editingRecipeId: recipe.id
            )
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
        }
        .onDisappear {
            AppDelegate.setAllowedOrientations(.portrait)
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

    // MARK: - Menu

    private var ownerMenu: some View {
        Menu {
            Button {
                showEdit = true
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

            ForEach(ingredientsWithStatus, id: \.ingredient.id) { status in
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
