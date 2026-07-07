import SwiftUI
import AVKit
import UIKit

struct AVPlayerTvos: UIViewControllerRepresentable {
    let player: AVPlayer
    let video: Video

    @Environment(VideoManager.self) private var videoManager
    @Environment(LibraryStore.self) private var cloudStore

    private static let skipSponsorActionId = UIAction.Identifier("cathode.skipSponsor")
    private static let bookmarkActionId = UIAction.Identifier("cathode.toggleBookmark")

    /// Delegate bridge for the native "Up Next" content proposal. Modeled on the
    /// same AVKit mechanism FinStream uses, but the proposal is timed to the end
    /// of the current video (see `updateContentProposal`) rather than a
    /// credits/offset lead-in.
    final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        var lastNextVideoID: String?
        var pendingNextVideo: Video?
        var onPlayNext: ((Video) -> Void)?

        func playerViewController(
            _ playerViewController: AVPlayerViewController,
            shouldPresent proposal: AVContentProposal
        ) -> Bool {
            let proposalVC = UpNextProposalViewController()
            proposalVC.dateOfAutomaticAcceptance = Date().addingTimeInterval(10)
            playerViewController.contentProposalViewController = proposalVC
            return true
        }

        func playerViewController(
            _ playerViewController: AVPlayerViewController,
            didAccept proposal: AVContentProposal
        ) {
            if let next = pendingNextVideo {
                onPlayNext?(next)
            }
        }

        func playerViewController(
            _ playerViewController: AVPlayerViewController,
            didReject proposal: AVContentProposal
        ) {
            // Leave the finished video on its last frame; user declined the next one.
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.delegate = context.coordinator
        controller.allowsPictureInPicturePlayback = true
        controller.transportBarIncludesTitleView = true
        controller.customInfoViewControllers = makeInfoTabs()
        controller.transportBarCustomMenuItems = [makeBookmarkAction()]
        controller.speeds = [
            AVPlaybackSpeed(rate: 0.5, localizedName: "0.5×"),
            AVPlaybackSpeed(rate: 1.0, localizedName: "1×"),
            AVPlaybackSpeed(rate: 1.25, localizedName: "1.25×"),
            AVPlaybackSpeed(rate: 2.0, localizedName: "2×")
        ]
        context.coordinator.onPlayNext = { [videoManager] next in videoManager.setVideo(next) }
        updateContentProposal(for: controller, coordinator: context.coordinator)
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.player !== player {
            uiViewController.player = player
        }
        context.coordinator.onPlayNext = { [videoManager] next in videoManager.setVideo(next) }
        updateContentProposal(for: uiViewController, coordinator: context.coordinator)
        // Skip Sponsor — only mutate on transition to avoid flicker.
        let inSponsor = videoManager.currentSponsorSegment != nil
        let hasAction = uiViewController.contextualActions.contains { $0.identifier == Self.skipSponsorActionId }
        if inSponsor && !hasAction {
            uiViewController.contextualActions = [makeSkipSponsorAction()]
        } else if !inSponsor && hasAction {
            uiViewController.contextualActions = []
        }

        // Keep the bookmark item in sync with library state (it can change here
        // or elsewhere in the app). Rebuild only on transition to avoid flicker.
        let desiredTitle = bookmarkTitle(isBookmarked: cloudStore.isBookmarked(video.id))
        let currentItem = uiViewController.transportBarCustomMenuItems
            .first { ($0 as? UIAction)?.identifier == Self.bookmarkActionId } as? UIAction
        if currentItem?.title != desiredTitle {
            uiViewController.transportBarCustomMenuItems = [makeBookmarkAction()]
        }
    }

    /// Attaches (or clears) the native content proposal for the first related
    /// video. Timed to fire ~1s before the current video ends so the "Up Next"
    /// card surfaces only as playback finishes — not at a mid-video offset.
    private func updateContentProposal(for controller: AVPlayerViewController, coordinator: Coordinator) {
        let next = videoManager.upNextVideos.first
        let newNextID = next?.id

        guard coordinator.lastNextVideoID != newNextID else { return }

        guard let next, let playerItem = player.currentItem else {
            player.currentItem?.nextContentProposal = nil
            coordinator.lastNextVideoID = nil
            coordinator.pendingNextVideo = nil
            return
        }

        // Duration of the *current* video. Prefer the model's value; fall back
        // to the player item. Bail without advancing the dedupe token if it's
        // unknown so a later update retries once duration is available.
        let durationSeconds: Double
        if let modelDuration = video.duration, modelDuration > 0 {
            durationSeconds = modelDuration
        } else {
            let itemDuration = playerItem.duration
            guard itemDuration.isValid, itemDuration.seconds.isFinite, itemDuration.seconds > 0 else { return }
            durationSeconds = itemDuration.seconds
        }

        coordinator.lastNextVideoID = newNextID
        coordinator.pendingNextVideo = next

        let proposalTime = CMTime(seconds: max(0, durationSeconds - 1), preferredTimescale: 1)
        let title = next.title
        let subtitle = next.channelTitle
        let thumbnailURL = next.thumbnailURL ?? next.mqThumbnailURL

        Task {
            let previewImage = await loadPreviewImage(from: thumbnailURL)
            await MainActor.run {
                let proposal = AVContentProposal(
                    contentTimeForTransition: proposalTime,
                    title: title,
                    previewImage: previewImage
                )
                proposal.metadata = [makeMetadataItem(.commonIdentifierDescription, value: subtitle)]
                // Countdown/auto-accept is driven by the proposal VC's
                // dateOfAutomaticAcceptance, not this interval.
                proposal.automaticAcceptanceInterval = 0
                playerItem.nextContentProposal = proposal
            }
        }
    }

    private func loadPreviewImage(from url: URL?) async -> UIImage? {
        guard let url else { return nil }
        let request = URLRequest(url: url)
        if let cached = URLCache.shared.cachedResponse(for: request),
           let image = UIImage(data: cached.data) {
            return image
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let image = UIImage(data: data) else { return nil }
            URLCache.shared.storeCachedResponse(CachedURLResponse(response: response, data: data), for: request)
            return image
        } catch {
            return nil
        }
    }

    private func makeMetadataItem(_ identifier: AVMetadataIdentifier, value: Any) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = value as? NSCopying & NSObjectProtocol
        item.extendedLanguageTag = "und"
        return item.copy() as! AVMetadataItem
    }

    private func makeInfoTabs() -> [UIViewController] {
        let comments = UIHostingController(
            rootView: PlayerCommentsTab(video: video)
                .environment(videoManager)
                .environment(cloudStore)
        )
        comments.title = "Comments"

        let related = UIHostingController(
            rootView: PlayerRelatedTab()
                .environment(videoManager)
                .environment(cloudStore)
        )
        related.title = "Related"

        return [comments, related]
    }

    private func makeSkipSponsorAction() -> UIAction {
        UIAction(title: "Skip Sponsor", identifier: Self.skipSponsorActionId) { [videoManager] _ in
            videoManager.skipCurrentSponsorSegment()
        }
    }

    private func bookmarkTitle(isBookmarked: Bool) -> String {
        isBookmarked ? "Remove Bookmark" : "Add Bookmark"
    }

    private func makeBookmarkAction() -> UIAction {
        let isBookmarked = cloudStore.isBookmarked(video.id)
        let image = UIImage(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
        return UIAction(title: bookmarkTitle(isBookmarked: isBookmarked),
                        image: image,
                        identifier: Self.bookmarkActionId) { [cloudStore, video] _ in
            cloudStore.toggleBookmark(video)
        }
    }
}
