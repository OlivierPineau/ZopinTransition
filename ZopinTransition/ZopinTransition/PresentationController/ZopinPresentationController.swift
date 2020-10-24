import Foundation
import UIKit

final class ZopinPresentationController: UIPresentationController {
    override var frameOfPresentedViewInContainerView: CGRect {
        return containerView?.frame ?? .zero
    }

    override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()
        presentedView?.frame = frameOfPresentedViewInContainerView
    }

    override var presentedView: UIView? {
        let presentedView = super.presentedView

        // HACK: This is a workaround for the bug described in: http://openradar.appspot.com/18005149
        // UIKit changes the frame of the `presentedView` outside of our control. We can change that frame in
        // `containerViewWillLayoutSubviews()` but it's too late in the process - if we do that it's visible that
        // the frame changes without an animation during dismissal.
        presentedView?.frame = frameOfPresentedViewInContainerView

        return presentedView
    }
}
