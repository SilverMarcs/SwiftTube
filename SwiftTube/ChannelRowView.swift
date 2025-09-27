// ChannelRowView.swift
import SwiftUI

struct ChannelRowView: View {
    let channel: Channel
    
    var body: some View {
        HStack {
            AsyncImage(url: URL(string: channel.thumbnailURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(.secondary.opacity(0.3))
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            VStack(alignment: .leading) {
                Text(channel.title)
                    .font(.headline)
                
                Text(channel.channelDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
    }
}