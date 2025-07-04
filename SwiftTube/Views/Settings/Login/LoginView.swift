import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    
    private var accountManager = AccountManager.shared
    @State private var instanceURL = "https://pipedapi.reallyaweso.me/"
    @State private var instanceName = "Piped"
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    var body: some View {
        Form {
            headerSection
            
            addAccountForm
        }
        .formStyle(.grouped)
    }
    
    private var headerSection: some View {
        Section {
            VStack  {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.accent)
                
                Text("SwiftTube")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Connect to your Piped instance")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .listRowBackground(Color.clear)
    }
    
    @ViewBuilder
    private var addAccountForm: some View {
        Section("Add Account") {
            TextField("Instance URL", text: $instanceURL)
                #if !os(macOS)
                .keyboardType(.URL)
                .autocapitalization(.none)
                #endif
                .autocorrectionDisabled()
            
            TextField("My Piped Instance", text: $instanceName)
            
            TextField("Username", text: $username)
                #if !os(macOS)
                .autocapitalization(.none)
                #endif
            
            SecureField("Password", text: $password)
        }
        
        Section {
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: login) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Add Account")
                }
            }
            .disabled(isLoading || username.isEmpty || password.isEmpty || instanceURL.isEmpty)
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
            
            isLoading = false
            
            if success {
                dismiss()
            } else {
                errorMessage = "Login failed. Please check your credentials and try again."
            }
        }
    }
}
