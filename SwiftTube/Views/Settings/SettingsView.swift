import SwiftUI

struct SettingsView: View {
    private var accountManager = AccountManager.shared
    @ObservedObject var config = Config.shared
    @State private var showingAddAccount = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Config") {
                    Toggle(isOn: $config.printDebug) {
                        Text("Print Debug Logs")
                    }
                }
                
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
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .toolbarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingAddAccount) {
            LoginView()
        }
    }
}

#Preview {
    SettingsView()
}
