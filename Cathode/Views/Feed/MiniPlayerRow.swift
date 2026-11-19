import SwiftUI

/// The now-playing row shown in the tab bar accessory and the macOS sidebar.
/// The play/pause button shows only when `togglePlayback` is set.
struct MiniPlayerRow<Artwork: View>: View {
    let title: String
    let subtitle: String
    var isPlaying = false
    var isLoading = false
    var transitionNamespace: Namespace.ID?
    var togglePlayback: (() -> Void)?
    @ViewBuilder let artwork: Artwork

    var body: some View {
        HStack {
            artwork
                .modifier(MiniPlayerSourceModifier(namespace: transitionNamespace))

            VStack(alignment: .leading) {
                Text(title)
                    .font(.system(size: 13))
                    .bold()
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let togglePlayback {
                Button(action: togglePlayback) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .contentTransition(.symbolEffect(.replace))
                }
                .disabled(isLoading)
                #if os(macOS)
                .keyboardShortcut(.space, modifiers: [])
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                #else
                .tint(.primary)
                #endif
            }
        }
        .contentShape(.rect)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        #if !os(macOS)
        .padding(.trailing, 4)
        #endif
    }
}

private struct MiniPlayerSourceModifier: ViewModifier {
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if let namespace {
            content.matchedTransitionSource(id: "MINIPLAYER", in: namespace)
        } else {
            content
        }
    }
}
