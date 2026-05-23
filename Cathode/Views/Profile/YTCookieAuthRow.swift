//
//  YTCookieAuthRow.swift
//  Cathode
//
//  Settings row for toggling YouTube cookie sign-in (history sync).
//

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
                    Text(detailText)
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
            #if os(tvOS)
            Label {
                Text("Waiting for iCloud sync")
                Text("Sign in to YouTube on your iPhone or iPad — the session will sync here automatically over iCloud.")
            } icon: {
                Image(systemName: "icloud.slash")
                    .foregroundStyle(.secondary)
            }
            #else
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
            #endif
        }
    }

    private var detailText: String {
        let base: String
        if auth.hydratedFromICloud {
            base = "Signed in via iCloud sync from another device."
        } else {
            base = "Watch progress will be reported to your YouTube account."
        }
        if let synced = auth.iCloudSyncedAt {
            return base + " iCloud: \(Self.relativeFormatter.localizedString(for: synced, relativeTo: .now))."
        }
        return base
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()
}
