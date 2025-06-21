//
//  SettingsToolbar.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import SwiftUI

// view modifier for toolbar items

extension View {
    func settingsToolbar(showSettings: Binding<Bool>) -> some View {
        self
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showSettings.wrappedValue.toggle()
                    }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: showSettings) {
                SettingsView()
            }
    }
}
