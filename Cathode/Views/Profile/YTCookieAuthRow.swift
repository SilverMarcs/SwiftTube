//
//  YTCookieAuthRow.swift
//  Cathode
//
//  Settings row for toggling YouTube cookie sign-in (history sync).
//

import SwiftUI

struct YTCookieAuthRow: View {
    private let auth = YTCookieAuth.shared
    @State private var showSheet = false
    @State private var confirmSignOut = false

    var body: some View {
        if auth.isSignedIn {
            Group {
                #if os(tvOS)
                Button(role: .destructive) {
                    confirmSignOut = true
                } label: {
                    HStack {
                        WatchHistorySyncLabel(status: auth.historySyncStatus)
                        Spacer()
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.red)
                    }
                }
                #else
                HStack {
                    WatchHistorySyncLabel(status: auth.historySyncStatus)
                    Spacer()
                    if auth.historySyncStatus == .needsSignIn {
                        Button("Sign In", systemImage: "person.badge.key") { showSheet = true }
                    }
                    Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                        confirmSignOut = true
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.red)
                }
                #endif
            }
            #if !os(tvOS)
            .sheet(isPresented: $showSheet) { YTCookieSignInView() }
            #endif
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
}
