import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var dataManager: DataManager
    @ObservedObject var authViewModel: AuthViewModel

    @State private var showAccount = false
    @State private var selectedTab: AppTab = .recipes

    private enum AppTab: Hashable { case recipes, plan, pantry, shopping }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                Tab("Recipes", systemImage: "list.bullet", value: AppTab.recipes) {
                    NavigationStack {
                        RecipeListScreen()
                            .toolbar { appToolbar() }
                    }
                }

                Tab("Plan", systemImage: "calendar", value: AppTab.plan) {
                    NavigationStack {
                        PlanView()
                            .toolbar { appToolbar() }
                    }
                }

                Tab("Pantry", systemImage: "refrigerator", value: AppTab.pantry) {
                    NavigationStack {
                        PantryView()
                            .toolbar { appToolbar() }
                    }
                }

                Tab("Shopping", systemImage: "cart", value: AppTab.shopping) {
                    NavigationStack {
                        ShoppingListView()
                            .toolbar { appToolbar() }
                    }
                }
            }
            .sheet(isPresented: $showAccount) {
                NavigationStack {
                    AccountView(authViewModel: authViewModel)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showAccount = false }
                                    .accessibilityIdentifier("account.done")
                            }
                        }
                }
            }

            errorBanner
        }
    }

    /// The gear that opens Account in a sheet. Each tab's own navigation stack shows it, so there is exactly
    /// one navigation bar per screen; tabs that sort add their own sort menu to the leading side.
    @ToolbarContentBuilder
    private func appToolbar() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showAccount = true
            } label: {
                Image(systemName: "gearshape").imageScale(.large)
            }
            .accessibilityLabel("Account")
            .accessibilityIdentifier("tabs.account")
        }
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let message = dataManager.errorMessage {
            VStack {
                Spacer()
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.white)
                    Text(message)
                        .foregroundColor(.white)
                        .font(.footnote)
                    Spacer()
                    Button {
                        dataManager.clearError()
                    } label: {
                        Image(systemName: "xmark").foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .glassEffect(.regular.tint(.red), in: .rect(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.bottom, 60)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.easeInOut, value: dataManager.errorMessage)
        }
    }
}
