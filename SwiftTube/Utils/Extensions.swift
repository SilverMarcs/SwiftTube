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
        let months = Int(timeInterval / 2629746) // Average month in seconds
        let years = Int(timeInterval / 31556952) // Average year in seconds
        
        if hours < 24 {
            return hours <= 1 ? "1 hour ago" : "\(hours) hours ago"
        } else if days < 7 {
            return days == 1 ? "1 day ago" : "\(days) days ago"
        } else if weeks < 4 {
            return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago"
        } else if months < 12 {
            return months == 1 ? "1 month ago" : "\(months) months ago"
        } else {
            return years == 1 ? "1 year ago" : "\(years) years ago"
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
        let pattern = "PT(?:(\\d+)H)?(?:(\\d+)M)?(?:(\\d+)S)?"
        let regex = try! NSRegularExpression(pattern: pattern)
        let matches = regex.firstMatch(in: self, range: NSRange(self.startIndex..., in: self))
        
        let hours = matches?.range(at: 1).location != NSNotFound ?
            Int(String(self[Range(matches!.range(at: 1), in: self)!])) ?? 0 : 0
        let minutes = matches?.range(at: 2).location != NSNotFound ?
            Int(String(self[Range(matches!.range(at: 2), in: self)!])) ?? 0 : 0
        let seconds = matches?.range(at: 3).location != NSNotFound ?
            Int(String(self[Range(matches!.range(at: 3), in: self)!])) ?? 0 : 0
        
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
