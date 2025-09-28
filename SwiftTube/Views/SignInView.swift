//
//  SignInView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 28/09/2025.
//

import SwiftUI

struct SignInView: View {
    private var tokenManager = GoogleAuthManager.shared
    
    @State private var isSigningIn = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack {
            if tokenManager.isSignedIn {
                HStack {
                    Text("Signed In with Google")
                    Spacer()
                    Button("Sign Out") {
                        tokenManager.clearTokens()
                    }
                    .foregroundStyle(.red)
                }
            } else {
                Button("Sign In With Google") {
                    signInWithGoogle()
                }
                .disabled(isSigningIn)
            }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }
    
    private func signInWithGoogle() {
        isSigningIn = true
        errorMessage = nil
        
        Task {
            do {
                try await tokenManager.signIn()
                isSigningIn = false
            } catch {
                isSigningIn = false
                errorMessage = "Sign-in failed: \(error.localizedDescription)"
            }
        }
    }
}