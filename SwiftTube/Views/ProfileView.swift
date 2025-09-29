//
//  ProfileView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 29/09/2025.
//

import SwiftUI
import SwiftMediaViewer

struct ProfileView: View {
    @State private var authManager = GoogleAuthManager.shared
    
    var body: some View {
        NavigationStack {
            Form {
                if authManager.isSignedIn {
                    HStack {
                        CachedAsyncImage(url: URL(string: authManager.avatarUrl), targetSize: 100)
                            .frame(width: 50, height: 50)
                        
                        Text(authManager.fullName)
                        
                        Spacer()
                    }
                } else {
                    SignInView()
                }
            }
            .task {
                try? await authManager.fetchUserInfo()
            }
            .navigationTitle("Profile")
            .toolbarTitleDisplayMode(.inlineLarge)
        }
    }
}
