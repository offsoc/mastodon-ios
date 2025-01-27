//
//  MediaPreviewVideoViewController.swift
//  Mastodon
//
//  Created by MainasuK on 2022-2-9.
//

import UIKit
import AVKit
import Combine
import func AVFoundation.AVMakeRect

final class MediaPreviewVideoViewController: UIViewController {

    var disposeBag = Set<AnyCancellable>()
    var viewModel: MediaPreviewVideoViewModel!
    
    let playerViewController = AVPlayerViewController()
    
    let previewImageView = UIImageView()
    
    deinit {
        viewModel.playbackState = .paused
    }
    
}

extension MediaPreviewVideoViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        playerViewController.willMove(toParent: self)
        addChild(playerViewController)
        playerViewController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(playerViewController.view)
        playerViewController.didMove(toParent: self)
        playerViewController.view.pinToParent()
        
        if let contentOverlayView = playerViewController.contentOverlayView {
            previewImageView.translatesAutoresizingMaskIntoConstraints = false
            contentOverlayView.addSubview(previewImageView)
            previewImageView.pinToParent()
        }
        
        playerViewController.delegate = self
        playerViewController.view.backgroundColor = .clear
        playerViewController.player = viewModel.player
        playerViewController.allowsPictureInPicturePlayback = true
        
        switch viewModel.item {
        case .video:
            break
        case .gif:
            playerViewController.showsPlaybackControls = false
        }
        
        viewModel.playbackState = .playing
     
        if let previewURL = viewModel.item.previewURL {
            previewImageView.contentMode = .scaleAspectFit
            previewImageView.af.setImage(
                withURL: previewURL,
                placeholderImage: .placeholder(color: .systemFill)
            )
            
            playerViewController.publisher(for: \.isReadyForDisplay)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] isReadyForDisplay in
                    guard let self = self else { return }
                    self.previewImageView.isHidden = isReadyForDisplay
                }
                .store(in: &disposeBag)
        }
    }
    
}

// MARK: - ShareActivityProvider
extension MediaPreviewVideoViewController: MediaPreviewPage {
    func setShowingChrome(_ showingChrome: Bool) {
        // TODO: does this do anything?
    }
}

// MARK: - AVPlayerViewControllerDelegate
extension MediaPreviewVideoViewController: AVPlayerViewControllerDelegate {
    
}


// MARK: - MediaPreviewTransitionViewController
extension MediaPreviewVideoViewController: MediaPreviewTransitionViewController {
    var mediaPreviewTransitionContext: MediaPreviewTransitionContext? {
        guard let playerView = playerViewController.view else { return nil }
        let _currentFrame: UIImage? = {
            guard let player = playerViewController.player else { return nil }
            guard let asset = player.currentItem?.asset else { return nil }
            let assetImageGenerator = AVAssetImageGenerator(asset: asset)
            assetImageGenerator.appliesPreferredTrackTransform = true   // fix orientation
            do {
                let cgImage = try assetImageGenerator.copyCGImage(at: player.currentTime(), actualTime: nil)
                let image = UIImage(cgImage: cgImage)
                return image
            } catch {
                return previewImageView.image
            }
        }()
        let _snapshot: UIView? = {
            guard let currentFrame = _currentFrame else { return nil }
            let size = AVMakeRect(aspectRatio: currentFrame.size, insideRect: view.frame).size
            let imageView = UIImageView(frame: CGRect(origin: .zero, size: size))
            imageView.image = currentFrame
            return imageView
        }()
        guard let snapshot = _snapshot else {
            return nil
        }
        
        return MediaPreviewTransitionContext(
            transitionView: playerView,
            snapshot: snapshot,
            snapshotTransitioning: snapshot
        )
    }
}

