import SwiftUI

struct LoginView: View {
    @StateObject private var accountManager = AccountManager.shared
    @State private var instanceURL = "https://pipedapi.kavin.rocks"
    @State private var instanceName = "Kavin Rocks"
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingAddAccount = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                headerSection
                
                if accountManager.accounts.isEmpty {
                    addAccountForm
                } else {
                    accountsList
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("SwiftTube")
            .toolbar {
                if !accountManager.accounts.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Add Account") {
                            showingAddAccount = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddAccount) {
                AddAccountSheet()
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
            Text("SwiftTube")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Connect to your Piped instance")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 40)
    }
    
    private var addAccountForm: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Instance URL")
                    .font(.headline)
                TextField("https://pipedapi.kavin.rocks", text: $instanceURL)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Instance Name")
                    .font(.headline)
                TextField("My Piped Instance", text: $instanceName)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Username")
                    .font(.headline)
                TextField("username", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.headline)
                SecureField("password", text: $password)
                    .textFieldStyle(.roundedBorder)
            }
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: login) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .tint(.white)
                } else {
                    Text("Login")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .disabled(isLoading || username.isEmpty || password.isEmpty || instanceURL.isEmpty)
        }
        .padding(.horizontal)
    }
    
    private var accountsList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Account")
                .font(.headline)
            
            LazyVStack(spacing: 12) {
                ForEach(accountManager.accounts) { account in
                    AccountRow(account: account) {
                        accountManager.setCurrentAccount(account)
                    }
                }
            }
        }
    }
    
    private func login() {
        guard !instanceURL.isEmpty, !username.isEmpty, !password.isEmpty else {
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            let success = await accountManager.addAccount(
                instanceURL: instanceURL,
                name: instanceName,
                username: username,
                password: password
            )
            
            await MainActor.run {
                isLoading = false
                if !success {
                    errorMessage = "Login failed. Please check your credentials and try again."
                }
            }
        }
    }
}

struct AccountRow: View {
    let account: Account
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(account.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

struct AddAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var accountManager = AccountManager.shared
    @State private var instanceURL = "https://pipedapi.kavin.rocks"
    @State private var instanceName = "Kavin Rocks"
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Instance URL")
                        .font(.headline)
                    TextField("https://pipedapi.kavin.rocks", text: $instanceURL)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Instance Name")
                        .font(.headline)
                    TextField("My Piped Instance", text: $instanceName)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Username")
                        .font(.headline)
                    TextField("username", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.headline)
                    SecureField("password", text: $password)
                        .textFieldStyle(.roundedBorder)
                }
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addAccount()
                    }
                    .disabled(isLoading || username.isEmpty || password.isEmpty || instanceURL.isEmpty)
                }
            }
        }
    }
    
    private func addAccount() {
        isLoading = true
        errorMessage = ""
        
        Task {
            let success = await accountManager.addAccount(
                instanceURL: instanceURL,
                name: instanceName,
                username: username,
                password: password
            )
            
            await MainActor.run {
                isLoading = false
                if success {
                    dismiss()
                } else {
                    errorMessage = "Login failed. Please check your credentials and try again."
                }
            }
        }
    }
}
