import SwiftUI

struct AccountView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @EnvironmentObject private var dataManager: DataManager
    @State private var showingAcknowledgements = false
    @State private var confirmingLogout = false
    @State private var confirmingDelete = false
    @State private var showingDeletePassword = false

    var body: some View {
        List {
            Section("Account") {
                LabeledContent("Email", value: authViewModel.user?.email ?? "Not logged in")
                    .accessibilityIdentifier("account.email")
            }

            Section("About") {
                LabeledContent("Version", value: AppInfo.currentVersionDescription)
                    .accessibilityIdentifier("account.version")
                if let url = AppLinks.privacyPolicy {
                    Link("Privacy policy", destination: url)
                        .accessibilityIdentifier("account.privacy")
                }
                Button("Acknowledgements") {
                    showingAcknowledgements = true
                }
                .accessibilityIdentifier("account.acknowledgements")
            }

            if authViewModel.user != nil {
                Section {
                    Button("Log Out", role: .destructive) {
                        confirmingLogout = true
                    }
                    .accessibilityIdentifier("account.logout")

                    Button("Delete Account", role: .destructive) {
                        confirmingDelete = true
                    }
                    .accessibilityIdentifier("account.delete")
                }
            }
        }
        .navigationTitle("Account")
        .sheet(isPresented: $showingAcknowledgements) {
            AcknowledgementsView()
        }
        .sheet(isPresented: $showingDeletePassword) {
            DeleteAccountView(authViewModel: authViewModel)
        }
        .confirmationDialog("Log out of FoodPlanner?", isPresented: $confirmingLogout, titleVisibility: .visible) {
            Button("Log Out", role: .destructive) { authViewModel.signOut() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Delete your account?", isPresented: $confirmingDelete, titleVisibility: .visible
        ) {
            Button("Continue", role: .destructive) { showingDeletePassword = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This is permanent. Your account and all of your recipes, including shared ones, "
                    + "your pantry and your shopping list will be deleted."
            )
        }
    }
}
