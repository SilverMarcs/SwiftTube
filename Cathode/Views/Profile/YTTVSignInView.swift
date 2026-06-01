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
            } else {
                signInButton

                if let activation = auth.pendingActivation {
                    pendingRow(activation)
                }
            }
        }
    }

    // MARK: - Signed in

    private var signedInRow: some View {
        Group {
            #if os(tvOS)
            Button(role: .destructive) {
                showSignOutConfirmation = true
            } label: {
                HStack(spacing: 12) {
                    avatar
                    Text(auth.accountName ?? "YouTube Account")
                    Spacer()
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(.red)
                }
            }
            #else
            HStack(spacing: 12) {
                avatar
                Text(auth.accountName ?? "YouTube Account")
                Spacer()
                Button(role: .destructive) {
                    showSignOutConfirmation = true
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                }
                .foregroundStyle(.red)
            }
            #endif
        }
        .alert("Are you sure you want to sign out?",
               isPresented: $showSignOutConfirmation) {
            Button("Sign Out", role: .destructive) { auth.signOut() }
            Button("Cancel", role: .cancel) { }
        }
    }

    @ViewBuilder
    private var avatar: some View {
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
    }

    // MARK: - Pending

    @ViewBuilder
    private func pendingRow(_ activation: YTTVAuthManager.ActivationInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Enter this code at youtube.com/activate")
                .font(.subheadline)
                #if !os(tvOS)
                .foregroundStyle(.secondary)
                #endif
            Text(activation.userCode)
                .font(.system(.title, design: .monospaced, weight: .bold))
                #if !os(tvOS)
                .textSelection(.enabled)
                #endif

            HStack {
                #if !os(tvOS)
                Link(destination: activation.verificationURL) {
                    Label("Open Activation Page", systemImage: "safari")
                }
                .buttonStyle(.borderedProminent)
                #else
                Text(activation.verificationURL.absoluteString)
                    .font(.footnote)
                #endif

                Spacer()

                Button("Cancel", role: .cancel) {
                    auth.cancelSignIn()
                }
            }

            Text("Waiting for activation…")
                .font(.footnote)
                #if !os(tvOS)
                .foregroundStyle(.secondary)
                #endif
        }
        #if os(tvOS)
        .foregroundStyle(.primary)
        #endif
    }

    // MARK: - Sign-in button

    private var signInButton: some View {
        Button {
            Task { await auth.beginSignIn() }
        } label: {
            Label("Sign in with YouTube", systemImage: "play.rectangle.fill")
        }
        .disabled(auth.pendingActivation != nil)
    }
}
