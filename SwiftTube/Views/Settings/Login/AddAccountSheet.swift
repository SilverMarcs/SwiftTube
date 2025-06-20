
struct AddAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var accountManager = AccountManager.shared
    @State private var instanceURL = "https://pipedapi.reallyaweso.me/"
    @State private var instanceName = "Piped"
    @State private var username = "SilverMarcs"
    @State private var password = "norfYp-duzhed-1porme"
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
            
            isLoading = false
            if success {
                dismiss()
            } else {
                errorMessage = "Login failed. Please check your credentials and try again."
            }
        }
    }
}
