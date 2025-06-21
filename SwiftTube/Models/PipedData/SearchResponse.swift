//
//  SearchResponse.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import Foundation

struct SearchResponse: Codable {
    let items: [Video]?
    let nextpage: String?
    let suggestion: String?
    let corrected: Bool?
}
