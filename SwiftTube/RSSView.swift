//
//  RSSView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import SwiftUI

struct RSSView: View {
    @Binding var rssLinks: [String]

    @State private var newLink: String = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(rssLinks.indices, id: \.self) { index in
                    Text(rssLinks[index])
                }
                .onDelete { indices in
                    rssLinks.remove(atOffsets: indices)
                }
            }
            .navigationTitle("RSS Links")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if !newLink.isEmpty {
                            rssLinks.append(newLink)
                            newLink = ""
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            
            TextField("Enter RSS URL", text: $newLink)
                .padding()
        }
    }
}
