# Migration Guide: VideoManager → NativeVideoManager

This guide outlines the migration from WebView-based `VideoManager` (using `YTPlayer`/`YTPlayerView`) to native AVPlayer-based `NativeVideoManager`.

## Overview

### Current Architecture (VideoManager)
- **Player**: `YTPlayer` (WebView-based YouTube iframe API)
- **View**: `YTPlayerView` (WebKit wrapper)
- **Pros**: Direct YouTube playback, built-in controls
- **Cons**: WebView overhead, limited customization, background playback restrictions

### New Architecture (NativeVideoManager)
- **Player**: `AVPlayer` (Native AVFoundation)
- **View**: `VideoPlayer` (SwiftUI native)
- **Pros**: Better performance, custom controls, PiP support, background audio
- **Cons**: Requires video URL extraction from YouTube

## NativeVideoManager Features

### Core Properties
```swift
private(set) var player: AVPlayer?
private(set) var isPlaying: Bool
var currentVideo: Video?
```

### Key Methods

#### Video Management
```swift
// Set video with autoplay (automatic via didSet)
nativeManager.currentVideo = video

// Set video without autoplay (for history restoration)
nativeManager.setVideoWithoutAutoplay(video)

// Load actual video content
nativeManager.loadVideo(url: videoURL, for: video, autoPlay: true)

// Dismiss current video
nativeManager.dismiss()
```

#### Playback Control
```swift
// Toggle play/pause
nativeManager.togglePlayPause()

// Pause/resume progress tracking
nativeManager.pauseTimerTracking()
nativeManager.resumeTimerTracking()
```

### Time Observer & Progress Tracking
- Automatically tracks playback every 5 seconds
- Saves progress to `UserDefaultsManager`
- Handles video completion (saves full duration)
- Prevents overwriting progress with 0 on video end

## Migration Steps

### 1. **Get Video URLs**
You need a way to extract the actual video URL from YouTube. Options:
- Use YouTube Data API v3 (doesn't provide direct video URLs)
- Use third-party libraries like [YoutubeExplode](https://github.com/alexeichhorn/YouTubeKit) for Swift
- Implement your own YouTube URL extraction

Example with a hypothetical video URL provider:
```swift
// In your view or view model
Task {
    if let videoURL = try? await YouTubeURLExtractor.getURL(for: video.id) {
        nativeManager.currentVideo = video
        nativeManager.loadVideo(url: videoURL, for: video, autoPlay: true)
    }
}
```

### 2. **Update Views**

#### Replace YTPlayerView with VideoPlayer
**Before (YTPlayerView):**
```swift
if let player = videoManager.player {
    YTPlayerView(player: player) {
        // Overlay content
    }
}
```

**After (Native VideoPlayer):**
```swift
if let player = nativeManager.player {
    VideoPlayer(player: player)
        .overlay {
            // Overlay content
        }
}
```

#### Update Environment Objects
**Before:**
```swift
@Environment(VideoManager.self) var manager
```

**After:**
```swift
@Environment(NativeVideoManager.self) var manager
```

### 3. **File-by-File Migration Checklist**

Files currently using `VideoManager`:

- [ ] `SwiftTubeApp.swift` - Already has both managers
- [ ] `ContentView.swift` - Update environment
- [ ] `VideoPlayerView.swift` - Replace YTPlayerView
- [ ] `MediaPlayerWindowView.swift` - Replace YTPlayerView
- [ ] `MiniPlayerAccessoryView.swift` - Update controls
- [ ] `ShortsView.swift` - Update pause/visibility logic
- [ ] `VideoCommentsView.swift` - Update environment
- [ ] `CompactVideoCard.swift` - Update video selection
- [ ] `VideoCard.swift` - Update video selection
- [ ] `VideoDetailView.swift` - Already uses NativeVideoManager ✓

### 4. **Feature Parity**

| Feature | VideoManager | NativeVideoManager | Status |
|---------|-------------|-------------------|---------|
| Play/Pause | ✅ | ✅ | Ready |
| Progress Tracking | ✅ | ✅ | Ready |
| History Management | ✅ | ✅ | Ready |
| Auto-play | ✅ | ✅ | Ready |
| Resume from Progress | ✅ | ✅ | Ready |
| Mini Player | ✅ | ⚠️ | Needs UI work |
| Fullscreen | ✅ | ⚠️ | Needs UI work |
| Playback Rate | ✅ | ⏳ | Todo |
| Quality Selection | ✅ | ⏳ | Todo |

### 5. **Missing VideoManager Features**

Features in `VideoManager` not yet in `NativeVideoManager`:

#### Expand/Collapse State
```swift
// Add to NativeVideoManager if needed
var isExpanded: Bool = false
var isMiniPlayerVisible: Bool = true
```

#### Platform-specific Features
```swift
#if os(macOS)
var isMediaPlayerWindowOpen: Bool = false
#endif
```

#### Restore Player State
```swift
// VideoManager has restoreIfNeeded() for WebView recovery
// For AVPlayer, you might need similar error recovery
func restoreIfNeeded() async {
    guard let currentVideo else { return }
    // Recreate player if needed
}
```

## Example: Complete View Migration

### Before
```swift
struct VideoPlayerView: View {
    @Environment(VideoManager.self) var manager
    
    var body: some View {
        if let player = manager.player {
            YTPlayerView(player: player) {
                CustomControlsOverlay()
            }
        }
    }
}
```

### After
```swift
struct VideoPlayerView: View {
    @Environment(NativeVideoManager.self) var manager
    
    var body: some View {
        if let player = manager.player {
            VideoPlayer(player: player)
                .overlay {
                    CustomControlsOverlay()
                }
                .onAppear {
                    manager.resumeTimerTracking()
                }
                .onDisappear {
                    manager.pauseTimerTracking()
                }
        }
    }
}
```

## Testing Strategy

1. **Unit Tests**: Test time observer and progress saving
2. **Integration Tests**: Test video selection and playback
3. **UI Tests**: Test play/pause, seek, and mini-player
4. **Manual Tests**: 
   - Video completion saves full duration
   - Background playback works
   - PiP mode works (if implemented)
   - Progress restoration on app restart

## Performance Considerations

- AVPlayer is more efficient than WebView for video playback
- Time observer runs every 5 seconds (same as before)
- Progress is saved to NSUbiquitousKeyValueStore (iCloud sync)
- Player cleanup happens automatically on `deinit`

## Known Limitations

1. **No Built-in YouTube Integration**: You must handle URL extraction
2. **No YouTube-specific Features**: Like captions from YouTube API
3. **Quality Selection**: Requires multiple URL variants
4. **DRM Content**: May not work with protected content

## Next Steps

1. ✅ Implement `NativeVideoManager` core functionality
2. ⏳ Choose YouTube URL extraction method
3. ⏳ Migrate views one by one
4. ⏳ Implement custom player controls
5. ⏳ Add PiP and background audio support
6. ⏳ Test thoroughly
7. ⏳ Remove old `VideoManager`, `YTPlayer`, `YTPlayerView`

## Additional Features to Consider

### Picture-in-Picture
```swift
import AVKit

// Enable PiP in NativeVideoManager
func enablePiP() {
    #if os(iOS)
    let pipController = AVPictureInPictureController(playerLayer: playerLayer)
    pipController?.startPictureInPicture()
    #endif
}
```

### Background Audio
```swift
import AVFoundation

// Configure audio session for background playback
func setupAudioSession() {
    let audioSession = AVAudioSession.sharedInstance()
    try? audioSession.setCategory(.playback, mode: .default)
    try? audioSession.setActive(true)
}
```

### Playback Rate Control
```swift
func setPlaybackRate(_ rate: Float) {
    player?.rate = rate
}
```

### Quality Selection
You'll need to:
1. Extract multiple quality URLs from YouTube
2. Store available qualities
3. Switch between them without losing progress

```swift
struct VideoQuality {
    let quality: String // "360p", "720p", "1080p"
    let url: URL
}

func switchQuality(to quality: VideoQuality) {
    let currentTime = player?.currentTime()
    let wasPlaying = isPlaying
    
    let newItem = AVPlayerItem(url: quality.url)
    player?.replaceCurrentItem(with: newItem)
    
    if let currentTime = currentTime {
        player?.seek(to: currentTime)
    }
    
    if wasPlaying {
        player?.play()
    }
}
```

## Resources

- [AVFoundation Documentation](https://developer.apple.com/documentation/avfoundation/)
- [VideoPlayer SwiftUI](https://developer.apple.com/documentation/avkit/videoplayer)
- [YouTube URL Extraction Libraries](https://github.com/alexeichhorn/YouTubeKit)
