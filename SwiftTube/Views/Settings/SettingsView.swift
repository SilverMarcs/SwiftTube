import SwiftUI
import Kingfisher

struct SettingsView: View {
    @ObservedObject private var accountManager = AccountManager.shared
    @ObservedObject private var config = Config.shared
    
    @State private var showingAddAccount = false
    @State private var deleteAlertPresented = false
    @State private var cacheSize: String = "Calculating..."
    
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
                
                Section("Debug") {
                    Toggle(isOn: $config.printDebug) {
                        Text("Print Debug Logs")
                    }
                    
                    Button {
                        deleteAlertPresented = true
                    } label: {
                        HStack {
                            Label {
                                Text("Clear Image Cache")
                                
                            } icon: {
                                Image(systemName: "trash")
                            }
                            
                            Spacer()
                            
                            Text("\(cacheSize)")
                        }
                    }
                    .alert("Clear Image Cache", isPresented: $deleteAlertPresented) {
                        Button("Clear", role: .destructive) {
                            ImageCache.default.clearCache()
                            calculateCacheSize()
                        }
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text("This will clear all cached images, freeing up storage space.")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .toolbarTitleDisplayMode(.inline)
            .task {
                calculateCacheSize()
            }
        }
        .sheet(isPresented: $showingAddAccount) {
            LoginView()
        }
    }
    
    private func calculateCacheSize() {
        ImageCache.default.calculateDiskStorageSize { result in
            Task { @MainActor in
                switch result {
                case .success(let size):
                    self.cacheSize = String(format: "%.2f MB", Double(size) / 1024 / 1024)
                case .failure:
                    self.cacheSize = "Unknown"
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
