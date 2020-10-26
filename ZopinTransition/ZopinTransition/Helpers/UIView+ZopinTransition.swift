import Foundation
import UIKit

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

        guard !hideSubviews else { return SnapshotView(snapshot: copy) }

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
                copy.addSubview(SnapshotLayerView(snapshotLayer: layerCopy))
                offset += 1
            }
        }

        return SnapshotView(snapshot: copy)
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
        copy.isOpaque = isOpaque
        copy.borderWidth = borderWidth
        copy.borderColor = borderColor
        copy.cornerRadius = cornerRadius
        copy.maskedCorners = maskedCorners
        copy.shadowPath = shadowPath
        copy.shadowColor = shadowColor
        copy.shadowOffset = shadowOffset
        copy.shadowRadius = shadowRadius
        copy.shadowOpacity = shadowOpacity
        copy.contents = contents
        copy.contentsRect = contentsRect
        copy.contentsGravity = contentsGravity
        copy.contentsScale = contentsScale
        copy.contentsCenter = contentsCenter
        copy.contentsFormat = contentsFormat
                
        copy.needsDisplayOnBoundsChange = true
        
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
