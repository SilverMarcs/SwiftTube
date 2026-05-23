//
//  UniversalProgressView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import SwiftUI

struct UniversalProgressView: View {
    var body: some View {
        ProgressView()
        #if os(tvOS)
            .tint(.white)
            .controlSize(.extraLarge)
            .scaleEffect(1.5)
        #else
            .controlSize(.large)
            .padding()
        #endif
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    UniversalProgressView()
}
