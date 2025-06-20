import Foundation

struct Account: Identifiable, Hashable {
    let id: String
    let instanceID: String
    let name: String
    let username: String
    let instance: Instance
    
    init(
        id: String? = nil,
        instanceID: String,
        name: String,
        username: String,
        instance: Instance
    ) {
        self.id = id ?? UUID().uuidString
        self.instanceID = instanceID
        self.name = name
        self.username = username
        self.instance = instance
    }
    
    var description: String {
        "\(username)@\(instance.name)"
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
