import Foundation

struct Instance: Identifiable, Hashable {
    let id: String
    let name: String
    let apiURLString: String
    
    init(id: String? = nil, name: String? = nil, apiURLString: String) {
        self.id = id ?? UUID().uuidString
        self.name = name ?? "Piped"
        self.apiURLString = apiURLString
    }
    
    var apiURL: URL? {
        URL(string: apiURLString)
    }
    
    var description: String {
        name.isEmpty ? apiURLString : "\(name) (\(apiURLString))"
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(apiURLString)
    }
}
