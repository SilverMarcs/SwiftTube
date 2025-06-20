import Foundation

struct Account: Identifiable, Hashable {
    let id: String
    let username: String
    let instance: Instance
    
    init(
        id: String? = nil,
        username: String,
        instance: Instance
    ) {
        self.id = id ?? UUID().uuidString
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
