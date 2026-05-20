//
//  YTTVSignInView.swift
//  Cathode
//
//  Sign-in UI for the YouTube TV device-code OAuth flow.
//  Replaces the easter-egg-gated Google OAuth SignInView for the rewrite.
//

import SwiftUI
import SwiftMediaViewer

struct YTTVSignInView: View {
    @Environment(YTTVAuthManager.self) private var auth
    @State private var showSignOutConfirmation = false

    var body: some View {
        Group {
            if auth.isSignedIn {
                signedInRow
            } else if let activation = auth.pendingActivation {
                pendingRow(activation)
            } else {
                signInButton
            }
        }
    }

    // MARK: - Signed in

    private var signedInRow: some View {
        HStack(spacing: 12) {
            if let url = auth.accountAvatarURL {
                CachedAsyncImage(url: url, targetSize: 100)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundStyle(.secondary)
            }

            Text(auth.accountName ?? "YouTube Account")

            Spacer()

            Button(role: .destructive) {
                showSignOutConfirmation = true
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
            }
            .foregroundStyle(.red)
        }
        .alert("Are you sure you want to sign out?",
               isPresented: $showSignOutConfirmation) {
            Button("Sign Out", role: .destructive) { auth.signOut() }
            Button("Cancel", role: .cancel) { }
        }
    }

    // MARK: - Pending

    @ViewBuilder
    private func pendingRow(_ activation: YTTVAuthManager.ActivationInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Enter this code at youtube.com/activate")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(activation.userCode)
                .font(.system(.title, design: .monospaced, weight: .bold))
                .textSelection(.enabled)

            HStack {
                #if !os(tvOS)
                Link(destination: activation.verificationURL) {
                    Label("Open Activation Page", systemImage: "safari")
                }
                .buttonStyle(.borderedProminent)
                #else
                Text(activation.verificationURL.absoluteString)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                #endif

                Spacer()

                Button("Cancel", role: .cancel) {
                    auth.cancelSignIn()
                }
            }

            Text("Waiting for activation…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Sign-in button

    private var signInButton: some View {
        Button {
            Task { await auth.beginSignIn() }
        } label: {
            Label("Sign in with YouTube", systemImage: "play.rectangle.fill")
        }
    }
}
