//
//  VideoRow.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import SwiftUI

struct VideoRow: View {
    let entry: Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AsyncImage(url: URL(string: entry.mediaGroup.thumbnail.url)) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fit)
                    .frame(maxHeight: 400)
            } placeholder: {
                Rectangle()
                    .fill(.background.secondary)
                    .aspectRatio(16/9, contentMode: .fit)
                    .frame(maxHeight: 400)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(entry.title)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack {
                    Text(entry.author.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text(entry.published.formatted())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
        }
        .background(.background.secondary, in: .rect(cornerRadius: 16))
    }
}
