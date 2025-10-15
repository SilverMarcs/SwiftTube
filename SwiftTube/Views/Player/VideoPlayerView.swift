//import SwiftUI
//import SwiftMediaViewer
//
//struct VideoPlayerView: View {
//    @Environment(VideoManager.self) var manager
//    @Environment(\.colorScheme) var colorScheme
//    @Environment(\.scenePhase) private var scenePhase
//    
//    @Binding var isCustomFullscreen: Bool
//    
//    var body: some View {
//        if isCustomFullscreen {
//            Color.black
//                .ignoresSafeArea()
//                .contentShape(Rectangle())
//        }
//    
//        else if manager.isExpanded, let video = manager.currentVideo {
//            CachedAsyncImage(url: URL(string: video.thumbnailURL), targetSize: 500)
//                .blur(radius: 10)
//                .overlay {
//                    if colorScheme == .dark {
//                        Color.black.opacity(0.85)
//                    } else {
//                        Color.white.opacity(0.85)
//                    }
//                }
//                .clipped()
//                .ignoresSafeArea()
//                .allowsHitTesting(false)
//                .aspectRatio(16/9, contentMode: .fit)
//        }
//                
//        if let player = manager.player {
//            YTPlayerView(player: player) {
//                Color.clear
//                    .overlay(alignment: .bottomTrailing) {
//                        Button {
//                            isCustomFullscreen.toggle()
//                        } label: {
//                            Image(systemName: isCustomFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
//                        }
//                        .buttonStyle(.glass)
//                        .buttonBorderShape(.circle)
//                        .controlSize(.small)
//                        .padding(10)
//                    }
//            }
//            .aspectRatio(16/9, contentMode: .fit)
//            .frame(maxWidth: isCustomFullscreen ? .infinity : nil,
//                   maxHeight: isCustomFullscreen ? .infinity : nil)
//            .ignoresSafeArea(edges: isCustomFullscreen ? .all : [])
//            .zIndex(manager.isExpanded ? 1000 : -1)
//            .allowsHitTesting(manager.isExpanded)
//            .onChange(of: isCustomFullscreen) {
//                if isCustomFullscreen {
//                    OrientationManager.shared.lockOrientation(.landscape, andRotateTo: .landscapeRight)
//                } else {
//                    OrientationManager.shared.lockOrientation(.all)
//                }
//            }
//            #if !os(macOS)
//            .onChange(of: scenePhase) {
//                if scenePhase == .active {
//                    Task { await manager.restoreIfNeeded() }
//                    manager.resumeTimerTracking()
//                } else if scenePhase == .background {
//                    manager.pauseTimerTracking()
//                }
//            }
//            #endif
//        }
//    }
//}
