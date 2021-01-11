import Foundation
import UIKit
import MapKit

@objc
extension UIView {
    var cornerRadius: CGFloat {
        get {
            return layer.cornerRadius
        }
        set {
            layer.cornerRadius = newValue
        }
    }
}

final class SnapshotView: UIView {
    private let snapshot: UIView
    private var initialSize: CGSize
    private var oldSize: CGSize
    
    @objc
    override var cornerRadius: CGFloat {
        get {
            return layer.cornerRadius
        }

        set {
            layer.cornerRadius = newValue
            snapshot.layer.cornerRadius = newValue
        }
    }

    override var frame: CGRect {
        didSet {
            let newSize = frame.size
            snapshot.frame = bounds
            
            guard oldSize.width != 0, oldSize.height != 0 else { return }
            
            if snapshot is MKAnnotationView {
                // I really don't know why
                return
            }
            
            if let unMappedView = snapshot as? UnMappedTransitioningView {
                if unMappedView.classForCodeString == "_MKUserLocationView" {
                    return
                }
            }

            for subview in snapshot.subviews {
                let widthRatio = subview.width / oldSize.width
                let heightRatio = subview.height / oldSize.height
                subview.frame = CGRect(x: subview.x / oldSize.width * width, y: subview.y / oldSize.height * height, width: widthRatio * width, height: heightRatio * height)
            }
            
            oldSize = newSize
        }
    }

    init(snapshot: UIView) {
        self.snapshot = snapshot
        self.initialSize = snapshot.size
        self.oldSize = snapshot.size
        super.init(frame: snapshot.frame)
        backgroundColor = .clear
        clipsToBounds = false
        addSubview(snapshot)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class SnapshotLayerView: UIView {
    private let containerView = UIView()
    private let snapshotLayer: CALayer
    private var initialSize: CGSize
    private var oldSize: CGSize
    
    init(snapshotLayer: CALayer) {
        self.snapshotLayer = snapshotLayer
        self.initialSize = snapshotLayer.frame.size
        self.oldSize = snapshotLayer.frame.size
        super.init(frame: snapshotLayer.frame)
        frame = snapshotLayer.frame
        
        backgroundColor = .clear
        clipsToBounds = false
        
        containerView.layer.addSublayer(snapshotLayer)
        
        containerView.backgroundColor = .clear
        containerView.clipsToBounds = false
        addSubview(containerView)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var frame: CGRect {
        didSet {
            containerView.frame = CGRect(
                x: (width - initialSize.width) / 2,
                y: (height - initialSize.height) / 2,
                width: initialSize.width,
                height: initialSize.height
            )
            snapshotLayer.frame = containerView.bounds

            guard initialSize.width != 0, initialSize.height != 0 else { return }

            let widthRatio = width / initialSize.width
            let heightRatio = height / initialSize.height

            containerView.transform = CGAffineTransform(scaleX: widthRatio, y: heightRatio)
            oldSize = size
        }
    }
}
