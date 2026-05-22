//
//  YTCookieAuthRow.swift
//  Cathode
//
//  Settings row for toggling YouTube cookie sign-in (history sync).
//

#if !os(tvOS)
import SwiftUI

struct YTCookieAuthRow: View {
    @Environment(YTCookieAuth.self) private var auth
    @State private var showSheet = false
    @State private var confirmSignOut = false

    var body: some View {
        if auth.isSignedIn {
            HStack {
                Label {
                    Text("YouTube history sync")
                    Text("Watch progress will be reported to your YouTube account.")
                } icon: {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                }
                Spacer()
                Button(role: .destructive) {
                    confirmSignOut = true
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                }
                .foregroundStyle(.red)
            }
            .alert("Stop syncing watch history?", isPresented: $confirmSignOut) {
                Button("Sign Out", role: .destructive) {
                    Task { await auth.signOut() }
                }
                Button("Cancel", role: .cancel) { }
            }
        } else {
            Button {
                showSheet = true
            } label: {
                Label {
                    Text("Enable YouTube history sync")
                    Text("Sign in to youtube.com so watch progress shows up on your account.")
                } icon: {
                    Image(systemName: "person.badge.key")
                }
            }
            .sheet(isPresented: $showSheet) {
                YTCookieSignInView()
            }
        }
    }
}
#endif
