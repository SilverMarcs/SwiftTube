import Foundation

struct Account: Identifiable, Hashable {
    let id: UUID = UUID()
    let username: String
    let instance: Instance
    
    init(
        username: String,
        instance: Instance
    ) {
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
