import SwiftUI

#if os(tvOS)
struct SeeAllCard: View {
    var body: some View {
        VStack {
            Image(systemName: "arrow.right.circle")
                .font(.largeTitle)
            Text("See All")
                .font(.headline)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background.secondary, in: .rect(cornerRadius: 12))
    }
}
#endif
