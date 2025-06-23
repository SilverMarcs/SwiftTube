////
////  VideoDetailView.swift
////  SwiftTube
////
////  Created by Zabir Raihan on 24/06/2025.
////
//
//
////
////  VideoPlayerView.swift
////  SwiftTube
////
////  Created by Zabir Raihan on 20/06/2025.
////
//
//import SwiftUI
//import YouTubePlayerKit
//
//struct VideoDetailView: View {
//    let video: Video
//    @Environment(\.videoNameSpace) private var namespace
//    @StateObject private var viewModel: VideoPlayerViewModel
//
//    init(video: Video) {
//        self.video = video
//        let player = YouTubePlayer(
//            // Possible values: .video, .videos, .playlist, .channel
//            source: .video(id: video.id),
//            // The parameters of the player
//            parameters: .init(
//                autoPlay: true,
//                showControls: true,
//            ),
//            // The configuration of the underlying web view
//            configuration: .init(
//                fullscreenMode: .system,
//                allowsInlineMediaPlayback: true,
//                allowsPictureInPictureMediaPlayback: true,
//            ))
//        self._viewModel = StateObject(wrappedValue: VideoPlayerViewModel(video: video, youTubePlayer: player))
//    }
//    
//    var youTubePlayer: YouTubePlayer {
//        viewModel.youTubePlayer
//    }
//    
//    
//    var body: some View {
//        VStack {
////            YouTubePlayerView(youTubePlayer) { state in
////                switch state {
////                case .idle:
////                    Rectangle()
////                        .fill(.background.secondary)
////                        .overlay {
////                            ProgressView()
////                        }
////                case .ready:
////                    EmptyView()
////                case .error(let error):
////                    ContentUnavailableView(
////                        "Error",
////                        systemImage: "exclamationmark.triangle.fill",
////                        description: Text("YouTube player couldn't be loaded: \(error.localizedDescription)")
////                    )
////                }
////            }
////            .aspectRatio(16/9, contentMode: .fit)
////            #if !os(macOS)
////            .navigationTransition(.zoom(sourceID: "video-\(video.id)", in: namespace ?? Namespace().wrappedValue))
////            #endif
//                     
//            ScrollView {
//                VideoInfoView(video: video)
//            }
//        }
//        #if !os(macOS)
//        .toolbar(.hidden, for: .navigationBar)
//        .toolbar(.hidden, for: .tabBar)
//        #endif
//    }
//}
//
