import SwiftUI

struct SettingsView: View {
    @StateObject private var accountManager = AccountManager.shared
    @State private var showingAddAccount = false
    
    var body: some View {
        NavigationStack {
            Form {
                // All Accounts Section
                if !accountManager.accounts.isEmpty {
                    Section("Accounts") {
                        ForEach(accountManager.accounts) { account in
                            LabeledContent {
                                if account.id == accountManager.currentAccount?.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else {
                                    Button("Switch") {
                                        accountManager.setCurrentAccount(account)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                }
                            } label: {
                                Text(account.instance.name)
                                Text("@\(account.username)")
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete", role: .destructive) {
                                    accountManager.removeAccount(account)
                                }
                            }
                        }
                    }
                }
                
                // Account Actions Section
                Section {
                    Button(action: {showingAddAccount = true }) {
                        Label {
                            Text("Add Account")
                        } icon: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .foregroundStyle(.blue)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbarTitleDisplayMode(.inlineLarge)
        }
        .sheet(isPresented: $showingAddAccount) {
            LoginView()
        }
    }
}

#Preview {
    SettingsView()
}
