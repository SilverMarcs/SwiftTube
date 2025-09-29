//
//  ProfileView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 29/09/2025.
//

import SwiftUI
import SwiftMediaViewer
import SwiftData

struct ProfileView: View {
    @State private var authManager = GoogleAuthManager.shared
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SignInView()
                }
            
                Section {
                    WatchLaterView()
                }
                
                Section {
                    HistoryView()
                }
            }
            .contentMargins(.top, 5)
            .task {
                try? await authManager.fetchUserInfo()
            }
            .navigationTitle("Profile")
            .toolbarTitleDisplayMode(.inlineLarge)
        }
    }
}
