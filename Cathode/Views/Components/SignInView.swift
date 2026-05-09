//
//  SignInView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 28/09/2025.
//

import SwiftUI
import SwiftMediaViewer

struct SignInView: View {
    @Environment(GoogleAuthManager.self) private var tokenManager

    @State private var isSigningIn = false
    @State private var showSignOutConfirmation = false   // NEW

    var body: some View {
        VStack {
            if tokenManager.isSignedIn {
                HStack {
                    CachedAsyncImage(url: URL(string: tokenManager.avatarUrl), targetSize: 100)
                        .frame(width: 40, height: 40)
                    
                    Text(tokenManager.fullName)

                    Spacer()

                    Button(role: .destructive) {
                        // Instead of signing out immediately, show confirmation
                        showSignOutConfirmation = true
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                    .foregroundStyle(.red)
                }
                .alert(
                    "Are you sure you want to sign out?",
                    isPresented: $showSignOutConfirmation
                ) {
                    Button("Sign Out", role: .destructive) {
                        tokenManager.clearTokens()
                    }
                    Button("Cancel", role: .cancel) { }
                }
            } else {
                Button("Sign In With Google") {
                    signInWithGoogle()
                }
                .disabled(isSigningIn)
            }
        }
    }

    private func signInWithGoogle() {
        isSigningIn = true

        Task {
            do {
                try await tokenManager.signIn()
            } catch { }
            isSigningIn = false
        }
    }
}
