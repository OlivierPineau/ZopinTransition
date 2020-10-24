import Foundation
import UIKit

public final class ZopinTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    private let presentationDuration: TimeInterval
    private let dismissalDuration: TimeInterval
    
    public init(transitionableViewController: TransitionableViewController, presentationDuration: TimeInterval = 0.35, dismissalDuration: TimeInterval = 0.35) {
        self.presentationDuration = presentationDuration
        self.dismissalDuration = dismissalDuration
        super.init()
        transitionableViewController.navigationController?.modalPresentationStyle = .custom
        transitionableViewController.modalPresentationStyle = .custom
    }
    
    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return ZopinTransitioning(isPresenting: true, duration: presentationDuration)
    }

    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return ZopinTransitioning(isPresenting: false, duration: dismissalDuration)
    }

    public func interactionControllerForPresentation(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        guard let interactiveTransitioning = animator as? UIViewControllerInteractiveTransitioning else { return nil }
        return interactiveTransitioning
    }

    public func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        guard let interactiveTransitioning = animator as? UIViewControllerInteractiveTransitioning else { return nil }
        return interactiveTransitioning
    }
}
