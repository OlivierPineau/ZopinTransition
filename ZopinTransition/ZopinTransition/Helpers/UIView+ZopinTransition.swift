import Foundation
import UIKit

extension UIView {
    func snapshot(shouldHideSubviews: Bool) -> UIView? {
        let visibleSubviews = subviews.filter { $0.alpha == 1 }

        if shouldHideSubviews {
            visibleSubviews.forEach { $0.alpha = 0 }
        }

        var finalSnapshot = snapshotView(afterScreenUpdates: true)
        finalSnapshot?.clipsToBounds = true
        finalSnapshot?.cornerRadius = cornerRadius

        // Snapshot view returns a view where the corner radius is 0
        // In order to have the corner radius and the shadow of the snapshotted view
        // We need to have the snapshot inside a container view,
        // The `SnapshotView` is responsable to resize the snapshot when its frame changes
        finalSnapshot = SnapshotView(snapshot: finalSnapshot)

        finalSnapshot?.setShadow(radius: layer.shadowRadius, offset: layer.shadowOffset, opacity: CGFloat(layer.shadowOpacity), color: UIColor(cgColor: layer.shadowColor ?? UIColor.clear.cgColor))
        finalSnapshot?.layer.shadowPath = layer.shadowPath

        if shouldHideSubviews {
            visibleSubviews.forEach { $0.alpha = 1 }
        }

        return finalSnapshot
    }

    func snapshotContent() -> UIView {
        let container = UIView(frame: frame)
        container.backgroundColor = .clear

        let snapshots = subviews.compactMap({ (view) -> UIView? in
            let snapshot = view.snapshot(shouldHideSubviews: false)
            snapshot?.frame = view.frame
            return snapshot
        })
        snapshots.forEach { container.addSubview($0) }
        return container
    }
}

extension UINavigationBar {
    func snapshotNavigationBar() -> UIView {
        return snapshotContent()
    }
}

extension UITabBar {
    func snapshotTabBar() -> UIView {
        return snapshotContent()
    }
}

extension UIView {
    func copyView(hideSubviews: Bool) -> UIView {
        let copy = extractCopy()
        copy.alpha = alpha
        copy.isHidden = isHidden

        copy.tintColor = tintColor
        copy.clipsToBounds = clipsToBounds
        copy.backgroundColor = backgroundColor ?? .clear

        copy.mask = mask?.copyView(hideSubviews: false)
        copy.transform = transform
        copy.autoresizingMask = autoresizingMask
        copy.autoresizesSubviews = autoresizesSubviews

        copy.layer.backgroundColor = layer.backgroundColor
        copy.layer.borderWidth = layer.borderWidth
        copy.layer.borderColor = layer.borderColor
        copy.layer.cornerRadius = layer.cornerRadius
        copy.layer.maskedCorners = layer.maskedCorners

        copy.layer.shadowPath = layer.shadowPath
        copy.layer.shadowColor = layer.shadowColor
        copy.layer.shadowOffset = layer.shadowOffset
        copy.layer.shadowRadius = layer.shadowRadius
        copy.layer.shadowOpacity = layer.shadowOpacity

        guard !hideSubviews else { return copy }

        if copy is UIVisualEffectView {
            return copy
        }

        let layers = layer.sublayers ?? []
        let subviewsLayers = subviews.map { $0.layer }

        var offset: Int = 0
        layers.enumerated().forEach { (index, layer) in
            if subviewsLayers.contains(layer) {
                let subviewCopy = subviews[index - offset].copyView(hideSubviews: hideSubviews)
                
                if let visualEffectView = copy as? UIVisualEffectView {
                    visualEffectView.contentView.addSubview(subviewCopy)
                } else {
                    copy.addSubview(subviewCopy)
                }

            } else {
                let layerCopy = layer.zopinCopy(hideSubviews: hideSubviews)
                copy.layer.addSublayer(layerCopy)
                offset += 1
            }
        }

        return copy
    }

    private func extractCopy() -> UIView {
        if let label = self as? UILabel {
            return label.zopinCopy()
        } else if let textfield = self as? UITextField {
            return textfield.zopinCopy()
        } else if let button = self as? UIButton {
            return button.zopinCopy()
        } else if let imageView = self as? UIImageView {
            return imageView.zopinCopy()
        } else if let scrollView = self as? UIScrollView {
            return scrollView.zopinCopy()
        } else if let visualEffectView = self as? UIVisualEffectView {
            return visualEffectView.zopinCopy()
        }

        return UIView(frame: frame)
    }
}

extension CALayer {
    func zopinCopy(hideSubviews: Bool) -> CALayer {
        let copy = extractCopy()
        copy.isHidden = isHidden
        copy.frame = frame
        copy.backgroundColor = backgroundColor
        copy.borderWidth = borderWidth
        copy.borderColor = borderColor
        copy.cornerRadius = cornerRadius
        copy.maskedCorners = maskedCorners
        copy.shadowPath = shadowPath
        copy.shadowColor = shadowColor
        copy.shadowOffset = shadowOffset
        copy.shadowRadius = shadowRadius
        copy.shadowOpacity = shadowOpacity

        return copy
    }

    private func extractCopy() -> CALayer {
        if let gradient = self as? CAGradientLayer {
            return gradient.zopinCopy()
        }

        return CALayer()
    }
}

private extension CAGradientLayer {
    func zopinCopy() -> CAGradientLayer {
        let gradient = CAGradientLayer()
        gradient.startPoint = startPoint
        gradient.endPoint = endPoint
        gradient.locations = locations
        gradient.colors = colors

        return gradient
    }
}

private extension UILabel {
    func zopinCopy() -> UILabel {
        let copy = UILabel(frame: frame)
        copy.text = text
        copy.attributedText = attributedText
        copy.textColor = textColor ?? .clear
        copy.font = font
        copy.numberOfLines = numberOfLines
        copy.textAlignment = textAlignment
        copy.adjustsFontSizeToFitWidth = adjustsFontSizeToFitWidth
        copy.lineBreakMode = lineBreakMode

        return copy
    }
}

private extension UITextField {
    func zopinCopy() -> UITextField {
        let copy = UITextField(frame: frame)
        copy.text = text
        copy.attributedText = attributedText
        copy.textColor = textColor ?? .clear
        copy.font = font
        copy.textAlignment = textAlignment
        copy.adjustsFontSizeToFitWidth = adjustsFontSizeToFitWidth

        return copy
    }
}

private extension UIButton {
    func zopinCopy() -> UIButton {
        let copy = UIButton(frame: frame)

        let states: [UIControl.State] = [.normal, .highlighted, .selected]
        states.forEach {
            copy.setBackgroundImage(backgroundImage(for: $0), for: $0)
        }

        return copy
    }
}

private extension UIImageView {
    func zopinCopy() -> UIImageView {
        let copy = UIImageView(frame: frame)
        copy.image = image
        copy.contentMode = contentMode
        
        return copy
    }
}

private extension UIScrollView {
    func zopinCopy() -> UIScrollView {
        let copy = UIScrollView(frame: frame)
        copy.contentInsetAdjustmentBehavior = contentInsetAdjustmentBehavior
        copy.contentSize = contentSize
        copy.contentInset = adjustedContentInset
        copy.contentOffset = contentOffset
        copy.showsVerticalScrollIndicator = showsVerticalScrollIndicator
        copy.showsHorizontalScrollIndicator = showsHorizontalScrollIndicator

        return copy
    }
}

private extension UIVisualEffectView {
    func zopinCopy() -> UIVisualEffectView {
        let copy = UIVisualEffectView(frame: frame)
        copy.effect = effect
        return copy
    }
}
