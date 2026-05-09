//
//  ExpandableText.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 28/09/2025.
//

import SwiftUI

struct ExpandableText: View {
    let text: String
    let maxCharacters: Int
    
    @State private var isExpanded = false
    private let needsExpansion: Bool
    
    init(text: String, maxCharacters: Int = 400) {
        self.text = text
        self.maxCharacters = maxCharacters
        self.needsExpansion = text.count > maxCharacters
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(LocalizedStringKey(displayedText))
                .textSelection(.enabled)
                .lineSpacing(2)
                .accentColor(.blue)
            
            if needsExpansion {
                Button {
                    isExpanded.toggle()
                } label: {
                    Text(isExpanded ? "Show Less" : "Show More")
                        .contentShape(.rect)
                }
                .buttonBorderShape(.capsule)
                .controlSize(.small)
            }
        }
    }
    
    private var displayedText: String {
        guard needsExpansion && !isExpanded else {
            return text
        }
        return String(text.prefix(maxCharacters))
    }
}
