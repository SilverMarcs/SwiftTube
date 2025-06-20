import Foundation

enum VideosApp: String, CaseIterable {
    case piped = "piped"
    
    var name: String {
        return "Piped"
    }
    
    var supportsAccounts: Bool {
        return true
    }
}
