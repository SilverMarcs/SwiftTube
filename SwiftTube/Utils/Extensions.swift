//
//  Extensions.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import Foundation

extension Date {
    func customRelativeFormat() -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(self)
        
        let hours = Int(timeInterval / 3600)
        let days = Int(timeInterval / 86400)
        let weeks = Int(timeInterval / 604800)
        let months = Int(timeInterval / 2629746)
        let years = Int(timeInterval / 31556952)
        
        if years > 0 {
            return "\(years)Y"
        } else if months > 0 {
            return "\(months)M"
        } else if weeks > 0 {
            return "\(weeks)W"
        } else if days > 0 {
            return "\(days)D"
        } else if hours > 0 {
            return "\(hours)H"
        } else {
            return "1H"  // Minimum display for anything less than an hour
        }
    }
}

extension Int {
    func formatDuration() -> String {
        let hours = self / 3600
        let minutes = (self % 3600) / 60
        let seconds = self % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    func formatNumber() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        
        if self >= 1_000_000 {
            return String(format: "%.1fM", Double(self) / 1_000_000)
        } else if self >= 1_000 {
            return String(format: "%.1fK", Double(self) / 1_000)
        } else {
            return formatter.string(from: NSNumber(value: self)) ?? String(self)
        }
    }
}

extension String {
    func formatNumber() -> String {
        guard let number = Int(self) else { return self }
        return number.formatNumber()
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

extension String {
    func parseDurationToSeconds() -> Int {
        print(self)
        let pattern = "PT(?:(\\d+)H)?(?:(\\d+)M)?(?:(\\d+)S)?"
        let regex = try! NSRegularExpression(pattern: pattern)
        let matches = regex.firstMatch(in: self, range: NSRange(self.startIndex..., in: self))
        
        guard let matches = matches else { return 0 }
        
        let hours = if let range = Range(matches.range(at: 1), in: self), matches.range(at: 1).location != NSNotFound {
            Int(String(self[range])) ?? 0
        } else { 0 }
        
        let minutes = if let range = Range(matches.range(at: 2), in: self), matches.range(at: 2).location != NSNotFound {
            Int(String(self[range])) ?? 0
        } else { 0 }
        
        let seconds = if let range = Range(matches.range(at: 3), in: self), matches.range(at: 3).location != NSNotFound {
            Int(String(self[range])) ?? 0
        } else { 0 }
        
        return hours * 3600 + minutes * 60 + seconds
    }
}

extension URL {
    var youtubeVideoID: String? {
        if host == "youtu.be" {
            return pathComponents.dropFirst().first
        } else if host == "www.youtube.com" || host == "youtube.com" {
            if path == "/watch" {
                return URLComponents(url: self, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "v" })?.value
            } else if path.starts(with: "/embed/") {
                return pathComponents.last
            }
        }
        return nil
    }
}
