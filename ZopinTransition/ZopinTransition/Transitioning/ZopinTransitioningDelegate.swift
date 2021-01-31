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
    
    private lazy var dismissalAnimationController = ZopinTransitioning(isPresenting: false, duration: dismissalDuration, timingParameters: dismissalTimingParameters, hasInteractiveStart: dismissalHasInteractiveStart)//, viewController: transitionableViewController as? InteractiveTransitionableViewController)
    
    private let dismissal = ModalTransitionAnimator(presenting: false)
    
    public init(transitionableViewController: TransitionableViewController, presentationDuration: TimeInterval = 0.35, presentationTimingParameters: UITimingCurveProvider = UICubicTimingParameters(animationCurve: .easeInOut), presentationHasInteractiveStart: Bool = false, dismissalDuration: TimeInterval = 0.35, dismissalTimingParameters: UITimingCurveProvider = UICubicTimingParameters(animationCurve: .easeInOut), dismissalHasInteractiveStart: Bool = false) {
        self.transitionableViewController = transitionableViewController
        self.presentationDuration = presentationDuration
        self.presentationTimingParameters = presentationTimingParameters
        self.presentationHasInteractiveStart = presentationHasInteractiveStart
        self.dismissalDuration = dismissalDuration
        self.dismissalTimingParameters = dismissalTimingParameters
        self.dismissalHasInteractiveStart = dismissalHasInteractiveStart
        super.init()
        transitionableViewController.navigationController?.modalPresentationStyle = .custom
        transitionableViewController.modalPresentationStyle = .custom
        
        if let interactiveTransitionableViewController = transitionableViewController as? InteractiveTransitionableViewController {
            interactionController = DismissalInteractionController(viewController: interactiveTransitionableViewController, transitionType: .scaleCenter)
        }
    }
        
    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        presentationAnimationController
    }

    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        dismissalAnimationController//dismissal//
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

//------------------------------------------------------------------------------------------------------
//------------------------------------------------------------------------------------------------------
//------------------------------------------------------------------------------------------------------
//------------------------------------------------------------------------------------------------------
//------------------------------------------------------------------------------------------------------
//------------------------------------------------------------------------------------------------------
//------------------------------------------------------------------------------------------------------
//------------------------------------------------------------------------------------------------------

class ModalTransitionAnimator: NSObject {
    private let isPresenting: Bool
    
    init(presenting: Bool) {//}, viewController: CustomPresentable) {
        self.isPresenting = presenting
        super.init()
    }
}

extension ModalTransitionAnimator: UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval { 0.5 }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        interruptibleAnimator(using: transitionContext).startAnimation()
    }
    
    func interruptibleAnimator(using transitionContext: UIViewControllerContextTransitioning) -> UIViewImplicitlyAnimating {
        isPresenting ? animatePresentation(using: transitionContext) : animateDismissal(using: transitionContext)
    }

    private func animatePresentation(using transitionContext: UIViewControllerContextTransitioning) -> UIViewPropertyAnimator {
        let presentedViewController = transitionContext.viewController(forKey: .to)!
        transitionContext.containerView.addSubview(presentedViewController.view)

        let presentedFrame = transitionContext.finalFrame(for: presentedViewController)
        let dismissedFrame = CGRect(x: presentedFrame.minX, y: transitionContext.containerView.bounds.height, width: presentedFrame.width, height: presentedFrame.height)

        presentedViewController.view.frame = dismissedFrame

        let animator = UIViewPropertyAnimator(duration: transitionDuration(using: transitionContext), dampingRatio: 1.0) {
            presentedViewController.view.frame = presentedFrame
        }

        animator.addCompletion { _ in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }

        return animator
    }

    private func animateDismissal(using transitionContext: UIViewControllerContextTransitioning) -> UIViewPropertyAnimator {
        let presentedViewController = transitionContext.viewController(forKey: .from)!
        let presentedFrame = transitionContext.finalFrame(for: presentedViewController)
        let dismissedFrame = CGRect(x: presentedFrame.minX, y: transitionContext.containerView.bounds.height, width: presentedFrame.width, height: presentedFrame.height)

        let timingParameters = UISpringTimingParameters(dampingRatio: 0.8, initialVelocity: CGVector(dx: 0, dy: 1))
        let animator = UIViewPropertyAnimator(duration: transitionDuration(using: transitionContext), timingParameters: timingParameters)
        animator.addAnimations {
            presentedViewController.view.frame = dismissedFrame
        }

        animator.addCompletion { _ in
            transitionContext.finishInteractiveTransition()
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }

        return animator
    }
    
    func cancelDismissal(using transitionContext: UIViewControllerContextTransitioning) {
        let presentedViewController = transitionContext.viewController(forKey: .from)!
        let presentedFrame = transitionContext.finalFrame(for: presentedViewController)
        
        let timingParameters = UISpringTimingParameters(dampingRatio: 0.8, initialVelocity: CGVector(dx: 0, dy: 1))
        let animator = UIViewPropertyAnimator(duration: transitionDuration(using: transitionContext), timingParameters: timingParameters)
        animator.addAnimations {
            presentedViewController.view.frame = presentedFrame
        }

        animator.addCompletion { _ in
            transitionContext.cancelInteractiveTransition()
        }
        
        animator.startAnimation()
    }
}
