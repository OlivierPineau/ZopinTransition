import Foundation
import UIKit

public final class ZopinTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    private let presentationDuration: TimeInterval
    private let presentationTimingParameters: UITimingCurveProvider
    private let dismissalDuration: TimeInterval
    private let dismissalTimingParameters: UITimingCurveProvider
    
    public init(transitionableViewController: TransitionableViewController, presentationDuration: TimeInterval = 0.35, presentationTimingParameters: UITimingCurveProvider = UICubicTimingParameters(animationCurve: .easeInOut),  dismissalDuration: TimeInterval = 0.35, dismissalTimingParameters: UITimingCurveProvider = UICubicTimingParameters(animationCurve: .easeInOut)) {
        self.presentationDuration = presentationDuration
        self.presentationTimingParameters = presentationTimingParameters
        self.dismissalDuration = dismissalDuration
        self.dismissalTimingParameters = dismissalTimingParameters
        super.init()
        transitionableViewController.navigationController?.modalPresentationStyle = .custom
        transitionableViewController.modalPresentationStyle = .custom
    }
    
    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return ZopinTransitioning(isPresenting: true, duration: presentationDuration, timingParameters: presentationTimingParameters)
    }

    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return ZopinTransitioning(isPresenting: false, duration: dismissalDuration, timingParameters: dismissalTimingParameters)
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
