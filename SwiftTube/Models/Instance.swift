import Foundation

struct Instance: Identifiable, Hashable {
    let id: String
    let name: String
    let apiURLString: String
    let app: VideosApp
    
    init(app: VideosApp = .piped, id: String? = nil, name: String? = nil, apiURLString: String) {
        self.app = app
        self.id = id ?? UUID().uuidString
        self.name = name ?? app.name
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
