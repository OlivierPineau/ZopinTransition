import Foundation
import UIKit

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
    private var snapshot: UIView?

    @objc
    override var cornerRadius: CGFloat {
        get {
            return layer.cornerRadius
        }

        set {
            layer.cornerRadius = newValue
            snapshot?.layer.cornerRadius = newValue
        }
    }

    override var frame: CGRect {
        didSet {
            snapshot?.frame = bounds
        }
    }

    init(snapshot: UIView?) {
        self.snapshot = snapshot
        super.init(frame: snapshot?.frame ?? .zero)
        backgroundColor = .clear

        if let snapshot = snapshot {
            addSubview(snapshot)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        snapshot?.frame = bounds
    }
}
