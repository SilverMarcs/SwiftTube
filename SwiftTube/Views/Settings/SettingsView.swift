import SwiftUI

struct SettingsView: View {
    @StateObject private var accountManager = AccountManager.shared
    @State private var showingAddAccount = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Current Account Section
                if let currentAccount = accountManager.currentAccount {
                    Section("Current Account") {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(currentAccount.name)
                                    .font(.headline)
                                Text("@\(currentAccount.username)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(currentAccount.instance.name)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
                
                // All Accounts Section
                if !accountManager.accounts.isEmpty {
                    Section("All Accounts") {
                        ForEach(accountManager.accounts, id: \.id) { account in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(account.name)
                                        .font(.headline)
                                    Text("@\(account.username)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(account.instance.name)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                
                                Spacer()
                                
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
                Section("Account Actions") {
                    Button(action: {
                        showingAddAccount = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                            Text("Add Account")
                        }
                    }
                    
                    if accountManager.currentAccount != nil {
                        Button(action: {
                            if let currentAccount = accountManager.currentAccount {
                                accountManager.removeAccount(currentAccount)
                            }
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundStyle(.red)
                                Text("Logout")
                            }
                        }
                        .foregroundStyle(.red)
                    }
                }
                
                // App Information Section
                Section("App Information") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $showingAddAccount) {
            LoginView()
        }
    }
}

#Preview {
    SettingsView()
}
