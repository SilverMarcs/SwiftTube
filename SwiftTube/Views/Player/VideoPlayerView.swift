import SwiftUI
import SwiftMediaViewer

struct VideoPlayerView: View {
    @Environment(VideoManager.self) var manager
    @Environment(\.colorScheme) var colorScheme
    
    @Binding var isCustomFullscreen: Bool
    @State private var isScrubbing = false
    @State private var pendingScrubTime: TimeInterval = 0
    @State private var showOverlays = false
    @State private var dragOffset: CGFloat = 0

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
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showOverlays.toggle()
                        }
                    }
                    .overlay(alignment: .center) {
                        if showOverlays {
                            centerControls
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if showOverlays {
                            playbackControls
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        if showOverlays {
                            Button {
                                showOverlays.toggle()
                                isCustomFullscreen.toggle()
                            } label: {
                                Image(systemName: isCustomFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                    .padding(4)
                                    .contentShape(.rect)
                            }
                            .tint(.white)
                            .buttonStyle(.glass)
                            .buttonBorderShape(.circle)
                            .padding()
                        }
                    }
            }
            .aspectRatio(16/9, contentMode: .fit)
            .frame(maxWidth: isCustomFullscreen ? .infinity : nil,
                   maxHeight: isCustomFullscreen ? .infinity : nil)
            .ignoresSafeArea(edges: isCustomFullscreen ? .all : [])
            .zIndex(manager.isExpanded ? 1000 : -1)
            .allowsHitTesting(manager.isExpanded)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.height
                    }
                    .onEnded { value in
                        let vertical = value.translation.height
                        let horizontal = value.translation.width
                        if abs(horizontal) < 40 { // mostly vertical swipe
                            if vertical < -40 && !isCustomFullscreen { // swipe up to enter fullscreen
                                isCustomFullscreen = true
                            } else if vertical > 40 && isCustomFullscreen { // swipe down to exit fullscreen
                                isCustomFullscreen = false
                            }
                        }
                       withAnimation(.easeInOut(duration: 0.2)) {
                            dragOffset = 0
                       }
                    }
            )
            .offset(y: dragOffset)
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
    func formatTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
    var centerControls: some View {
        HStack(spacing: 15) {
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
                    if manager.isPlaying {
                        showOverlays = false
                    }
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
        let sliderRange: ClosedRange<Double> = duration > 0 ? 0...duration : 0...1
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
            HStack {
                Text(formatTime(manager.playbackPosition))
                    .foregroundStyle(.white)
                    .font(.caption)
                
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
                
                Text(formatTime(duration))
                    .foregroundStyle(.white)
                    .font(.caption)
                
                Menu {
                    ForEach([0.5, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                        Button {
                            Task {
                                await manager.setPlaybackRate(rate)
                            }
                        } label: {
                            HStack {
                                Text("\(rate, specifier: "%.2g")x")
                                if manager.playbackRate == rate {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "slider.vertical.3")
                        .padding(4)
                        .contentShape(.rect)
                        .tint(.white)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 4)
            .glassEffect()
        }
        .frame(maxWidth: .infinity)
        .padding(10)
    }
}
