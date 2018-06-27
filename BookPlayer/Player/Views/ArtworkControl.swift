//
//  ArtworkView.swift
//  BookPlayer
//
//  Created by Florian Pichler on 22.06.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

class ArtworkControl: UIView, UIGestureRecognizerDelegate {
    @IBOutlet var contentView: UIView!

    @IBOutlet private weak var rewindIcon: PlayerJumpIconRewind!
    @IBOutlet private weak var forwardIcon: PlayerJumpIconForward!
    @IBOutlet private weak var playPauseButton: UIButton!

    @IBOutlet private weak var artworkContainer: UIView!
    @IBOutlet private weak var artworkImage: BPArtworkView!
    @IBOutlet weak var artworkWidth: NSLayoutConstraint!
    @IBOutlet weak var artworkHeight: NSLayoutConstraint!

    private let playImage = UIImage(named: "playerIconPlay")
    private let pauseImage = UIImage(named: "playerIconPause")

    private var pan: UIPanGestureRecognizer!

    // Based on the design files for iPhone X where the regular artwork is 325dp and the paused state is 255dp in width
    private let artworkScalePaused: CGFloat = 255.0 / 325.0
    private let jumpIconAlpha: CGFloat = 0.15
    private let jumpIconOffset: CGFloat = 25.0
    private var triggeredPanAction: Bool = false

    var onPlayPause: ((ArtworkControl) -> Void)?
    var onRewind: ((ArtworkControl) -> Void)?
    var onForward: ((ArtworkControl) -> Void)?

    var iconColor: UIColor {
        get {
            return self.rewindIcon.tintColor
        }

        set {
            self.rewindIcon.tintColor = newValue
            self.forwardIcon.tintColor = newValue
        }
    }

    var borderColor: UIColor {
        get {
            return UIColor(cgColor: self.artworkImage.layer.borderColor!)
        }

        set {
            self.artworkImage.layer.borderColor = newValue.withAlphaComponent(0.2).cgColor
        }
    }

    var artwork: UIImage? {
        get {
            return self.artworkImage.image
        }

        set {
            self.artworkImage.image = newValue

            let ratio = self.artworkImage.imageRatio
            let base = min(self.artworkContainer.bounds.width, self.artworkContainer.bounds.height)

            self.artworkHeight.constant = ratio < 1 ? base * ratio : base
            self.artworkWidth.constant = ratio > 1 ? base / ratio : base
        }
    }

    var shadowOpacity: CGFloat {
        get {
            return CGFloat(self.artworkImage.layer.shadowOpacity)
        }
        set {
            self.artworkImage.layer.shadowOpacity = Float(newValue)
        }
    }

    var isPlaying: Bool = false {
        didSet {
            self.playPauseButton.setImage(self.isPlaying ? self.pauseImage : self.playImage, for: UIControlState())

            UIView.animate(
                withDuration: 0.25,
                delay: 0.0,
                usingSpringWithDamping: 0.6,
                initialSpringVelocity: 1.4,
                options: .preferredFramesPerSecond60,
                animations: {
                    if self.isPlaying {
                        self.artworkImage.transform = .identity
                    } else {
                        self.artworkImage.transform = CGAffineTransform(scaleX: self.artworkScalePaused, y: self.artworkScalePaused)
                    }

                    self.setTransformForJumpIcons()
                }
            )

            self.showPlayPauseButton()
        }
    }

    // MARK: - Lifecycle

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        self.setup()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.setup()
    }

    private func setup() {
        self.backgroundColor = .clear

        // Load & setup xib
        Bundle.main.loadNibNamed("ArtworkControl", owner: self, options: nil)

        self.addSubview(self.contentView)

        self.contentView.frame = self.bounds
        self.contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // View & Subviews
        self.artworkContainer.layer.shadowColor = UIColor.black.cgColor
        self.artworkContainer.layer.shadowOffset = CGSize(width: 0.0, height: 4.0)
        self.artworkContainer.layer.shadowOpacity = 0.15
        self.artworkContainer.layer.shadowRadius = 12.0

        self.rewindIcon.alpha = self.jumpIconAlpha
        self.forwardIcon.alpha = self.jumpIconAlpha

        self.artworkImage.clipsToBounds = false
        self.artworkImage.contentMode = .scaleAspectFit
        self.artworkImage.layer.cornerRadius = 6.0
        self.artworkImage.layer.masksToBounds = true

        // Gestures
        self.pan = UIPanGestureRecognizer(target: self, action: #selector(panAction))
        self.pan.delegate = self
        self.pan.maximumNumberOfTouches = 1
        self.pan.cancelsTouchesInView = true

        self.addGestureRecognizer(self.pan!)
    }

    override func layoutIfNeeded() {

    }

    func setTransformForJumpIcons() {
        if self.isPlaying {
            self.rewindIcon.transform = CGAffineTransform(translationX: self.jumpIconOffset, y: 0.0)
            self.forwardIcon.transform = CGAffineTransform(translationX: -self.jumpIconOffset, y: 0.0)
        } else {
            self.rewindIcon.transform = .identity
            self.forwardIcon.transform = .identity
        }
    }

    // MARK: - Actions

    @IBAction private func playPauseButtonTouchUpInside() {
        self.onPlayPause?(self)
    }

    // MARK: - Public API

    func showPlayPauseButton(_ animated: Bool = true) {
        let fadeIn = {
            self.playPauseButton.alpha = 1.0
        }

        let fadeOut = {
            self.playPauseButton.alpha = 0.05
        }

        if animated || self.playPauseButton.alpha < 1.0 {
            UIView.animate(withDuration: 0.3, delay: 0, options: .allowUserInteraction, animations: fadeIn, completion: { (_: Bool) in
                UIView.animate(withDuration: 0.3, delay: 2.2, options: .allowUserInteraction, animations: fadeOut, completion: nil)
            })
        } else {
            UIView.animate(withDuration: 0.3, delay: 2.2, options: .allowUserInteraction, animations: fadeOut, completion: nil)
        }
    }

    // MARK: - Gesture recognizers

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == self.pan {
            return limitPanAngle(self.pan, degreesOfFreedom: 45.01, comparator: .lessThan)
        }

        return true
    }

    private func updateArtworkViewForTranslation(_ xTranslation: CGFloat) {
        let sign: CGFloat = xTranslation < 0 ? -1 : 1
        let width: CGFloat = self.rewindIcon.bounds.width
        let actionThreshold: CGFloat = width - 10.0
        let maximumPull: CGFloat = width + 5.0
        let translation: CGFloat = rubberBandDistance(fabs(xTranslation), dimension: width * 2 + 10.0, constant: 0.6)

        self.artworkContainer.transform = CGAffineTransform(translationX: translation * sign, y: 0)

        let factor: CGFloat = min(translation / actionThreshold, 1.0)
        let alpha: CGFloat = self.jumpIconAlpha + (1.0 - self.jumpIconAlpha) * factor
        let offset: CGFloat = self.isPlaying ? self.jumpIconOffset * (1 - factor) : 0.0

        if !self.triggeredPanAction {
            if xTranslation > 0 {
                self.rewindIcon.alpha = alpha
                self.rewindIcon.transform = CGAffineTransform(translationX: offset, y: 0.0)
            } else {
                self.forwardIcon.alpha = alpha
                self.forwardIcon.transform = CGAffineTransform(translationX: -offset, y: 0.0)
            }
        }

        if translation > actionThreshold && !self.triggeredPanAction {
            if #available(iOS 10.0, *) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }

            UIView.animate(withDuration: 0.20, delay: 0.0, options: .curveEaseIn, animations: {
                self.rewindIcon.alpha = self.jumpIconAlpha
                self.forwardIcon.alpha = self.jumpIconAlpha
            })

            if sign < 0 {
                self.onForward?(self)
            } else {
                self.onRewind?(self)
            }

            self.triggeredPanAction = true
        }

        if translation > maximumPull {
            self.resetArtworkViewHorizontalConstraintAnimated()

            self.pan.isEnabled = false
            self.pan.isEnabled = true
        }
    }

    func resetArtworkViewHorizontalConstraintAnimated() {
        UIView.animate(
            withDuration: 0.3,
            delay: 0.0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 1.5,
            options: .preferredFramesPerSecond60,
            animations: {
                self.artworkContainer.transform = .identity
            }
        )

        UIView.animate(withDuration: 0.1, delay: 0.10, options: .curveEaseIn, animations: {
            self.rewindIcon.alpha = self.jumpIconAlpha
            self.forwardIcon.alpha = self.jumpIconAlpha

            self.setTransformForJumpIcons()
        })

        self.triggeredPanAction = false
    }

    @objc private func panAction(gestureRecognizer: UIPanGestureRecognizer) {
        guard gestureRecognizer.isEqual(self.pan) else {
            return
        }

        switch gestureRecognizer.state {
            case .began:
                gestureRecognizer.setTranslation(CGPoint(x: 0, y: 0), in: self)

            case .changed:
                let translation = gestureRecognizer.translation(in: self)

                self.updateArtworkViewForTranslation(translation.x)

            case .ended, .cancelled, .failed:
                self.resetArtworkViewHorizontalConstraintAnimated()

            case .possible: break
        }
    }
}
