//
//  Date++.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import Foundation


extension Date {
    var relativeTime: String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(self)
        
        let days = Int(timeInterval / 86400)
        let weeks = days / 7
        let months = days / 30
        let years = days / 365
        
        if years > 0 {
            return "\(years) year\(years == 1 ? "" : "s") ago"
        } else if months > 0 {
            return "\(months) month\(months == 1 ? "" : "s") ago"
        } else if weeks > 0 {
            return "\(weeks) week\(weeks == 1 ? "" : "s") ago"
        } else if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s") ago"
        } else {
            return "Today"
        }
    }
}
