//
//  Config.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import Foundation
import SwiftUI
import Combine

class Config: ObservableObject {
    static let shared = Config()
    
    private init() {}
    
    // MARK: - API Configuration
    @AppStorage("printDebug") var printDebug = false
}
