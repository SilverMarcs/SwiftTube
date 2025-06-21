//
//  Logger.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import Foundation

struct Logger {
    static func logAPIResponse(_ data: Data, endpoint: String = "No endpoint", method: String = "GET") {
        guard Config.shared.printDebug else { return }
        
        guard let json = try? JSONSerialization.jsonObject(with: data),
              let prettyPrintedData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
              let prettyPrintedString = String(data: prettyPrintedData, encoding: .utf8) else {
            print("Failed to format JSON response for \(method) \(endpoint)")
            return
        }
        
        print("\n=== Raw API Response for \(method) \(endpoint) ===")
        print(prettyPrintedString)
        print("==========================================\n")
    }
    
    static func logError(_ message: String) {
        guard Config.shared.printDebug else { return }
        print("Error: \(message)")
    }
}
