//
//  UpNextProposalViewController.swift
//  Cathode
//
//  The tvOS "Up Next" card shown at the end of a video. Modeled on FinStream's
//  NextEpisodeProposalViewController — same AVKit content-proposal mechanism —
//  but presents a single related YouTube video instead of a series episode.
//

import SwiftUI
import AVKit

@MainActor
final class UpNextProposalViewController: AVContentProposalViewController {
    private var remainingSeconds: Int = 0
    private var countdownTask: Task<Void, Never>?

    // MARK: - UI Components

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 24
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let upNextLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .semibold)
        label.textColor = .white.withAlphaComponent(0.7)
        return label
    }()

    private let thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 52, weight: .bold)
        label.textColor = .white
        label.numberOfLines = 2
        return label
    }()

    private let channelLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 29, weight: .regular)
        label.textColor = .white.withAlphaComponent(0.85)
        label.numberOfLines = 1
        return label
    }()

    private let buttonStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 32
        stack.alignment = .center
        return stack
    }()

    private lazy var playButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Play Next"
        config.image = UIImage(systemName: "play.fill")
        config.imagePadding = 12
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 40, bottom: 20, trailing: 48)
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(playTapped), for: .primaryActionTriggered)
        return button
    }()

    private lazy var cancelButton: UIButton = {
        var config = UIButton.Configuration.bordered()
        config.title = "Dismiss"
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 48, bottom: 20, trailing: 48)
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(cancelTapped), for: .primaryActionTriggered)
        return button
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        playerViewController?.playbackControlsIncludeTransportBar = false
        super.viewDidLoad()
        configureContent()
        setupHierarchy()
        setupConstraints()
        startCountdown()
    }

    override func viewWillDisappear(_ animated: Bool) {
        playerViewController?.playbackControlsIncludeTransportBar = true
        super.viewWillDisappear(animated)
        stopCountdown()
    }

    // MARK: - Setup

    private func setupHierarchy() {
        view.addSubview(contentStack)

        contentStack.addArrangedSubview(upNextLabel)
        contentStack.addArrangedSubview(thumbnailImageView)
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(channelLabel)

        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 16).isActive = true
        contentStack.addArrangedSubview(spacer)

        buttonStack.addArrangedSubview(playButton)
        buttonStack.addArrangedSubview(cancelButton)
        contentStack.addArrangedSubview(buttonStack)
    }

    private func setupConstraints() {
        playButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 440),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 247),

            contentStack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 80),
            contentStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -400),
        ])
    }

    private func configureContent() {
        guard let proposal = contentProposal else { return }

        titleLabel.text = proposal.title

        if let previewImage = proposal.previewImage {
            thumbnailImageView.image = previewImage
        }

        Task {
            for item in proposal.metadata where item.identifier == .commonIdentifierDescription {
                if let channel = try? await item.load(.value) as? String {
                    channelLabel.text = channel
                }
            }
        }
    }

    // MARK: - Countdown

    private func computeInitialRemainingSeconds() -> Int {
        if let autoDate = dateOfAutomaticAcceptance {
            return max(0, Int(autoDate.timeIntervalSince(Date()).rounded()))
        }
        return 0
    }

    private func startCountdown() {
        remainingSeconds = computeInitialRemainingSeconds()
        updateUpNextLabel()

        countdownTask?.cancel()
        countdownTask = Task { @MainActor in
            while !Task.isCancelled && self.remainingSeconds > 0 {
                try? await Task.sleep(for: .seconds(1))
                self.tickCountdown()
            }
        }
    }

    private func stopCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
    }

    private func tickCountdown() {
        remainingSeconds -= 1
        updateUpNextLabel()

        if remainingSeconds <= 0 {
            stopCountdown()
            dismissContentProposal(for: .accept, animated: true)
        }
    }

    private func updateUpNextLabel() {
        upNextLabel.text = "UP NEXT • \(remainingSeconds)s"
    }

    // MARK: - Player Frame

    override var preferredPlayerViewFrame: CGRect {
        guard let containerFrame = playerViewController?.view.frame else { return .zero }

        let width: CGFloat = 640
        let height: CGFloat = 360
        let padding: CGFloat = 80

        return CGRect(
            x: containerFrame.width - width - padding,
            y: padding,
            width: width,
            height: height
        )
    }

    // MARK: - Actions

    @objc private func playTapped() {
        stopCountdown()
        dismissContentProposal(for: .accept, animated: true)
    }

    @objc private func cancelTapped() {
        stopCountdown()
        dismissContentProposal(for: .reject, animated: true)
    }
}
