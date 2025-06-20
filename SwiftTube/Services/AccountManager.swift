import Foundation
import Combine

final class AccountManager: ObservableObject {
    static let shared = AccountManager()
    
    @Published var accounts: [Account] = []
    @Published var currentAccount: Account?
    
    private let userDefaults = UserDefaults.standard
    private let accountsKey = "saved_accounts"
    private let currentAccountKey = "current_account_id"
    
    private init() {
        loadAccounts()
        if let lastAccountId = userDefaults.string(forKey: currentAccountKey),
           let account = accounts.first(where: { $0.id == lastAccountId }) {
            setCurrentAccount(account)
        }
    }
    
    func addAccount(instanceURL: String, name: String, username: String, password: String) async -> Bool {
        let instance = Instance(name: name, apiURLString: instanceURL)
        let account = Account(
            instanceID: instance.id,
            name: name,
            username: username,
            instance: instance
        )
        
        let api = PipedAPI.shared
        await api.login(username: username, password: password, account: account)
        
        if api.isAuthenticated {
            accounts.append(account)
            saveAccounts()
            setCurrentAccount(account)
            return true
        } else {
            return false
        }
    }
    
    func removeAccount(_ account: Account) {
        accounts.removeAll { $0.id == account.id }
        
        // Clear keychain data
        KeychainManager.shared.deleteAccountData(account)
        
        if currentAccount?.id == account.id {
            currentAccount = nil
            userDefaults.removeObject(forKey: currentAccountKey)
        }
        
        saveAccounts()
    }
    
    func setCurrentAccount(_ account: Account) {
        currentAccount = account
        userDefaults.set(account.id, forKey: currentAccountKey)
    }
    
    private func saveAccounts() {
        let accountData = accounts.map { account in
            [
                "id": account.id,
                "instanceID": account.instanceID,
                "name": account.name,
                "username": account.username,
                "instanceName": account.instance.name,
                "instanceURL": account.instance.apiURLString
            ]
        }
        userDefaults.set(accountData, forKey: accountsKey)
    }
    
    private func loadAccounts() {
        guard let accountsData = userDefaults.array(forKey: accountsKey) as? [[String: String]] else {
            return
        }
        
        accounts = accountsData.compactMap { data in
            guard let id = data["id"],
                  let instanceID = data["instanceID"],
                  let name = data["name"],
                  let username = data["username"],
                  let instanceName = data["instanceName"],
                  let instanceURL = data["instanceURL"] else {
                return nil
            }
            
            let instance = Instance(
                id: instanceID,
                name: instanceName,
                apiURLString: instanceURL
            )
            
            return Account(
                id: id,
                instanceID: instanceID,
                name: name,
                username: username,
                instance: instance
            )
        }
    }
}
