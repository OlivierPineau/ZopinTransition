import Foundation
import UIKit

public final class ZopinTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    private let transitionableViewController: TransitionableViewController
    private let presentationDuration: TimeInterval
    private let presentationTimingParameters: UITimingCurveProvider
    private let presentationHasInteractiveStart: Bool
    private let dismissalDuration: TimeInterval
    private let dismissalTimingParameters: UITimingCurveProvider
    private let dismissalHasInteractiveStart: Bool
    
    private var interactionController: DismissalInteractionController?
    
    private lazy var presentationAnimationController = ZopinTransitioning(isPresenting: true, duration: presentationDuration, timingParameters: presentationTimingParameters, hasInteractiveStart: presentationHasInteractiveStart)
    
    private lazy var dismissalAnimationController = ZopinTransitioning(isPresenting: false, duration: dismissalDuration, timingParameters: dismissalTimingParameters, hasInteractiveStart: dismissalHasInteractiveStart)
    
    public init(transitionableViewController: TransitionableViewController, presentationDuration: TimeInterval = 0.35, presentationTimingParameters: UITimingCurveProvider = UICubicTimingParameters(animationCurve: .easeInOut), presentationHasInteractiveStart: Bool = false, dismissalDuration: TimeInterval = 0.35, dismissalTimingParameters: UITimingCurveProvider = UICubicTimingParameters(animationCurve: .easeInOut), dismissalHasInteractiveStart: Bool = false) {
        self.transitionableViewController = transitionableViewController
        self.presentationDuration = presentationDuration
        self.presentationTimingParameters = presentationTimingParameters
        self.presentationHasInteractiveStart = presentationHasInteractiveStart
        self.dismissalDuration = dismissalDuration
        self.dismissalTimingParameters = dismissalTimingParameters
        self.dismissalHasInteractiveStart = dismissalHasInteractiveStart
        super.init()
        transitionableViewController.navigationController?.modalPresentationStyle = .fullScreen
        transitionableViewController.modalPresentationStyle = .fullScreen
        
        if let interactiveTransitionableViewController = transitionableViewController as? InteractiveTransitionableViewController {
            interactionController = DismissalInteractionController(viewController: interactiveTransitionableViewController, transitionType: .dragAndScale)//scaleCenter
            interactionController?.delegate = self
        }
    }
        
    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        presentationAnimationController
    }

    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        dismissalAnimationController
    }
    
    public func interactionControllerForPresentation(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        guard let interactionController = interactionController,
              interactionController.interactionInProgress
        else {
            return nil
        }
        return interactionController
    }

    public func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        guard let interactionController = interactionController,
              interactionController.interactionInProgress
        else {
            return nil
        }
        return interactionController
    }
}

extension ZopinTransitioningDelegate: DismissalInteractionControllerDelegate {
    func willStartInteractiveTransition(with transitionContext: UIViewControllerContextTransitioning) {
        
    }
    
    func cancelInteractiveTransition(with initialSpringVelocity: CGFloat, _ transitionContext: UIViewControllerContextTransitioning) {
        
    }
    
    func finishInteractiveTransition(with initialSpringVelocity: CGFloat, _ transitionContext: UIViewControllerContextTransitioning) {
        dismissalAnimationController.updateAnimator(using: transitionContext)
    }
}
