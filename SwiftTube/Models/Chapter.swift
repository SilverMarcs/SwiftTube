import Foundation

struct Chapter: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let startTime: TimeInterval
    let thumbnailURL: URL?
    
    var startTimeText: String {
        let hours = Int(startTime) / 3600
        let minutes = Int(startTime) % 3600 / 60
        let seconds = Int(startTime) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
