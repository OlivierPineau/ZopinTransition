import Foundation
import MapKit
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
                let subview = subviews[index - offset]
                
                let subviewCopy = subview.copyView(hideSubviews: hideSubviews)
                
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
        } else if let activityIndicatorView = self as? UIActivityIndicatorView {
            return activityIndicatorView.zopinCopy()
        } else if let visualEffectView = self as? UIVisualEffectView {
            return visualEffectView.zopinCopy()
        } else if let mk = self as? MKMarkerAnnotationView {
            return mk.zopinCopy()
        }

        return UnMappedTransitioningView(frame: frame, classForCoderString: String(describing: self.classForCoder))
    }
}

final class UnMappedTransitioningView: UIView {
    public let classForCodeString: String
    
    init(frame: CGRect, classForCoderString: String) {
        self.classForCodeString = classForCoderString
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension CALayer {
    func zopinCopy(hideSubviews: Bool) -> CALayer {
        let copy = extractCopy()
        copy.delegate = delegate
        copy.position = position
        copy.anchorPoint = anchorPoint
        copy.zPosition = zPosition
        copy.transform = transform
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
        copy.contentsScale = contentsScale
        copy.contentsCenter = contentsCenter
        copy.contentsGravity = contentsGravity
        copy.contentsScale = contentsScale
        copy.contentsCenter = contentsCenter
        copy.contentsFormat = contentsFormat
        copy.rasterizationScale = rasterizationScale
        copy.shouldRasterize = shouldRasterize
        copy.needsDisplayOnBoundsChange = true
        copy.minificationFilter = minificationFilter
        copy.magnificationFilter = magnificationFilter
        copy.minificationFilterBias = minificationFilterBias
        
        guard !hideSubviews else { return copy }

        sublayers?.forEach {
            copy.addSublayer($0.zopinCopy(hideSubviews: hideSubviews))
        }

        return copy
    }

    private func extractCopy() -> CALayer {
        if let gradient = self as? CAGradientLayer {
            return gradient.zopinCopy()
        } else if let shapeLayer = self as? CAShapeLayer {
            return shapeLayer.zopinCopy()
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

private extension CAShapeLayer {
    func zopinCopy() -> CAShapeLayer {
        let shape = CAShapeLayer()
        shape.path = path
        shape.fillColor = fillColor
        shape.fillRule = fillRule
        shape.lineCap = lineCap
        shape.lineDashPattern = lineDashPattern
        shape.lineDashPhase = lineDashPhase
        shape.lineJoin = lineJoin
        shape.lineWidth = lineWidth
        shape.miterLimit = miterLimit
        shape.strokeColor = strokeColor
        shape.strokeStart = strokeStart
        shape.strokeEnd = strokeEnd
        return shape
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

private extension UIActivityIndicatorView {
    func zopinCopy() -> UIActivityIndicatorView {
        let copy = UIActivityIndicatorView(frame: frame)
        copy.style = style
        copy.hidesWhenStopped = hidesWhenStopped
        copy.color = color
        
        if isAnimating {
            copy.startAnimating()
        }
        
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

private extension MKMarkerAnnotationView {
    func zopinCopy() -> MKMarkerAnnotationView {
        let copy = MKMarkerAnnotationView(frame: frame)
        copy.titleVisibility = titleVisibility
        copy.subtitleVisibility = subtitleVisibility
        copy.markerTintColor = markerTintColor
        copy.glyphTintColor = glyphTintColor
        copy.glyphText = glyphText
        copy.glyphImage = glyphImage
        copy.selectedGlyphImage = selectedGlyphImage
        copy.animatesWhenAdded = animatesWhenAdded

        copy.image = image
        copy.centerOffset = centerOffset
        copy.calloutOffset = calloutOffset
        copy.isEnabled = isEnabled
        copy.isHighlighted = isHighlighted
        copy.isSelected = isSelected
        copy.canShowCallout = canShowCallout
        copy.leftCalloutAccessoryView = leftCalloutAccessoryView
        copy.rightCalloutAccessoryView = rightCalloutAccessoryView
        copy.detailCalloutAccessoryView = detailCalloutAccessoryView
        copy.isDraggable = isDraggable
        copy.dragState = dragState
        copy.collisionMode = collisionMode
        
        return copy
    }
}
