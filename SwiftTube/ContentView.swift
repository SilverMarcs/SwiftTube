//
//  ContentView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 20/06/2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var accountManager = AccountManager.shared
    
    var body: some View {
        FeedView()
    }
}
