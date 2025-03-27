//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit
import MediaPlayer

class VolumeView: MPVolumeView {
    override func volumeSliderRect(forBounds bounds: CGRect) -> CGRect {
        // The default implementation doesn't layout properly so we override this method to have a more consistent positioning
        return bounds
    }

    override func routeButtonRect(forBounds bounds: CGRect) -> CGRect {
        // The API to hide the routeButton is deprecated without replacement so we make it hidden here
        return CGRect.zero
    }
}

class MediaPlaybackViewController: UIViewController {
    let volumeControl = VolumeView(frame: CGRect.zero)
    let player = MPMusicPlayerController.systemMusicPlayer

    @IBOutlet weak var backButton: UIButton?
    @IBOutlet weak var playPauseButton: UIButton?
    @IBOutlet weak var forwardButton: UIButton?
    @IBOutlet weak var volumeContainerView: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        volumeControl.frame = volumeContainerView?.bounds ?? CGRect.zero
        volumeControl.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        volumeContainerView?.addSubview(volumeControl)

        backButton?.tintColor = UIColor.label
        playPauseButton?.tintColor = UIColor.label
        forwardButton?.tintColor = UIColor.label
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        player.beginGeneratingPlaybackNotifications()

        NotificationCenter.default.addObserver(self,
                                               selector:#selector(playStateChanged(_:)),
                                               name: Notification.Name.MPMusicPlayerControllerPlaybackStateDidChange,
                                               object: player)

        updateUI()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        player.endGeneratingPlaybackNotifications()
        NotificationCenter.default.removeObserver(self)
    }

    @IBAction func togglePlayPause(_ btn: UIButton?) {
        if player.playbackState == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

    @IBAction func back(_ btn: UIButton?) {
        player.skipToPreviousItem()
    }

    @IBAction func forward(_ btn: UIButton?) {
        player.skipToNextItem()
    }

    @objc func playStateChanged(_ notification: Notification) {
		updateUI()
    }

    func updateUI () {
        if player.playbackState == .playing {
            playPauseButton?.setImage(UIImage(named: "ic_pause"), for: .normal)
            playPauseButton?.setImage(UIImage(named: "ic_pause"), for: .selected)
            playPauseButton?.setImage(UIImage(named: "ic_pause"), for: .highlighted)
        } else {
            playPauseButton?.setImage(UIImage(named: "ic_play_arrow"), for: .normal)
            playPauseButton?.setImage(UIImage(named: "ic_play_arrow"), for: .selected)
            playPauseButton?.setImage(UIImage(named: "ic_play_arrow"), for: .highlighted)
        }
    }
}
