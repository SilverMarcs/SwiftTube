import SwiftUI
import SwiftMediaViewer

struct VideoPlayerView: View {
    @Environment(VideoManager.self) var manager
    @Environment(\.colorScheme) var colorScheme
    
    @Binding var isCustomFullscreen: Bool
    @State private var isScrubbing = false
    @State private var pendingScrubTime: TimeInterval = 0

    var body: some View {
        if isCustomFullscreen {
            Color.black
                .ignoresSafeArea()
                .contentShape(Rectangle())
        }
    
        else if manager.isExpanded, let video = manager.currentVideo {
            CachedAsyncImage(url: URL(string: video.thumbnailURL), targetSize: 500)
                .blur(radius: 10)
                .overlay {
                    if colorScheme == .dark {
                        Color.black.opacity(0.85)
                    } else {
                        Color.white.opacity(0.85)
                    }
                }
                .clipped()
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .aspectRatio(16/9, contentMode: .fit)
        }
                
        if let player = manager.player {
            YTPlayerView(player: player) {
                Color.clear
                    .allowsHitTesting(false)
                    .contentShape(Rectangle())
                    .overlay(alignment: .center) {
                        centerControls
                    }
                    .overlay(alignment: .bottom) {
                        playbackControls
                    }
            }
            .aspectRatio(16/9, contentMode: .fit)
            .frame(maxWidth: isCustomFullscreen ? .infinity : nil,
                   maxHeight: isCustomFullscreen ? .infinity : nil)
            .ignoresSafeArea(edges: isCustomFullscreen ? .all : [])
            .zIndex(manager.isExpanded ? 1000 : -1)
            .allowsHitTesting(manager.isExpanded)
            .onChange(of: isCustomFullscreen) {
                if isCustomFullscreen {
                    OrientationManager.shared.lockOrientation(.landscape, andRotateTo: .landscapeRight)
                } else {
                    OrientationManager.shared.lockOrientation(.all)
                }
            }
            .onAppear {
                pendingScrubTime = manager.playbackPosition
            }
            .onChange(of: manager.playbackPosition) {
                if !isScrubbing {
                    pendingScrubTime = manager.playbackPosition
                }
            }
            .onChange(of: manager.playbackDuration) {
                guard let duration = manager.playbackDuration, isScrubbing else { return }
                pendingScrubTime = min(max(pendingScrubTime, 0), duration)
            }
        }
    }
}

private extension VideoPlayerView {
    var centerControls: some View {
        HStack {
            Button {
                Task {
                    await manager.seek(by: -10)
                }
            } label: {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 30))
                    .padding(5)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            
            Button {
                Task {
                    await manager.togglePlayPause()
                }
            } label: {
                Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 40))
                    .padding()
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            
            Button {
                Task {
                    await manager.seek(by: 10)
                }
            } label: {
                Image(systemName: "goforward.10")
                    .font(.system(size: 30))
                    .padding(5)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
        }
    }
    
    var playbackControls: some View {
        let duration = manager.playbackDuration ?? manager.currentVideo?.duration.map(Double.init) ?? 0
        let sliderRange = duration > 0 ? 0...duration : 0...1
        let lowerBound = sliderRange.lowerBound
        let upperBound = sliderRange.upperBound
        let sliderBinding = Binding<Double>(
            get: {
                let value = isScrubbing ? pendingScrubTime : manager.playbackPosition
                return min(max(value, lowerBound), upperBound)
            },
            set: { newValue in
                isScrubbing = true
                let clamped = min(max(newValue, lowerBound), upperBound)
                pendingScrubTime = clamped
            }
        )
        
        return HStack(spacing: 5) {
            Slider(
                value: sliderBinding,
                in: sliderRange,
                onEditingChanged: { editing in
                    if !editing {
                        isScrubbing = false
                        let target = pendingScrubTime
                        Task {
                            await manager.seek(to: target)
                        }
                    }
                }
            )
            .disabled(duration <= 0)
            .frame(maxWidth: .infinity)
            .controlSize(.small)
            .sliderThumbVisibility(.hidden)
            .padding(.horizontal, 15)
            .padding(.vertical, 4)
            .glassEffect()
            
            Button {
                isCustomFullscreen.toggle()
            } label: {
                Image(systemName: isCustomFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .contentShape(.rect)
                    .padding(4)
            }
            .tint(.white)
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
    }
}
