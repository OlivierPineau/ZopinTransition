import UIKit

public typealias CustomPresentableViewController = UIViewController & CustomPresentable

public protocol CustomPresentable {
    var initialDismissalScrollView: UIScrollView? { get }
}

public protocol InteractionControlling {//}: UIViewControllerInteractiveTransitioning {
    var interactionInProgress: Bool { get }
}

final class PullToDismissInteractionController: NSObject {
    var interactionInProgress = false
    private weak var viewController: CustomPresentableViewController?
    private weak var transitionContext: UIViewControllerContextTransitioning?

    private var interactionDistance: CGFloat = 0
    private var interruptedTranslation: CGFloat = 0
    private var presentedFrame: CGRect?
    private var cancellationAnimator: UIViewPropertyAnimator?

    private lazy var gesture = UIPanGestureRecognizer(target: self, action: #selector(handleGesture(_:)))
    private var interactionEnabledViews = [UIView]()
    
    private var activeScrollView: UIScrollView?
    
    init(viewController: CustomPresentableViewController) {
        self.viewController = viewController
        super.init()
        prepareGestureRecognizer(in: viewController.view)
    }

    private func prepareGestureRecognizer(in view: UIView) {
        view.addGestureRecognizer(gesture)

        if let scrollView = viewController?.initialDismissalScrollView {
            prepareGesture(on: scrollView)
        }
    }
    
    private func prepareGesture(on scrollView: UIScrollView) {
        gesture.delegate = self
        scrollView.panGestureRecognizer.require(toFail: gesture)
        self.activeScrollView = scrollView
    }
    
    func onDismissalHandlingScrollViewOverride(_ scrollView: UIScrollView?) {
        if let scrollView = scrollView {
            prepareGesture(on: scrollView)
        } else {
            activeScrollView?.removeGestureRecognizer(gesture)
        }
    }
}

extension PullToDismissInteractionController {//}: InteractionControlling {
//    func startInteractiveTransition(_ transitionContext: UIViewControllerContextTransitioning) {
//        let presentedViewController = transitionContext.viewController(forKey: .from)!
//        presentedFrame = transitionContext.finalFrame(for: presentedViewController)
//        self.transitionContext = transitionContext
//        interactionDistance = transitionContext.containerView.bounds.height - presentedFrame!.minY
//    }

    func update(progress: CGFloat) {
        guard let transitionContext = transitionContext,
            let presentedFrame = presentedFrame,
            let presentedViewController = transitionContext.viewController(forKey: .from)
        else { return }
        transitionContext.updateInteractiveTransition(progress)
        
        presentedViewController.view.frame = CGRect(x: presentedFrame.minX, y: presentedFrame.minY + interactionDistance * progress, width: presentedFrame.width, height: presentedFrame.height)
        updateProgressivePresentationController(progress: 1.0 - progress)
    }

    func cancel(initialSpringVelocity: CGFloat) {
        guard let transitionContext = transitionContext,
            let presentedFrame = presentedFrame,
            let presentedViewController = transitionContext.viewController(forKey: .from)
        else { return }

        let timingParameters = UISpringTimingParameters(dampingRatio: 0.8, initialVelocity: CGVector(dx: 0, dy: initialSpringVelocity))
        cancellationAnimator = UIViewPropertyAnimator(duration: 0.5, timingParameters: timingParameters)

        cancellationAnimator?.addAnimations {
            presentedViewController.view.frame = presentedFrame
            self.updateProgressivePresentationController(progress: 1)
        }

        cancellationAnimator?.addCompletion { [weak self] _ in
            transitionContext.cancelInteractiveTransition()
            transitionContext.completeTransition(false)
            self?.interactionInProgress = false
        }

        enableOtherTouches()
        cancellationAnimator?.startAnimation()
    }

    func finish(initialSpringVelocity: CGFloat) {
        guard let transitionContext = transitionContext,
              let presentedFrame = presentedFrame,
              let presentedViewController = transitionContext.viewController(forKey: .from)
        else { return }
        
        let dismissedFrame = CGRect(x: presentedFrame.minX, y: transitionContext.containerView.bounds.height, width: presentedFrame.width, height: presentedFrame.height)

        let timingParameters = UISpringTimingParameters(dampingRatio: 0.8, initialVelocity: CGVector(dx: 0, dy: initialSpringVelocity))
        let finishAnimator = UIViewPropertyAnimator(duration: 0.5, timingParameters: timingParameters)

        finishAnimator.addAnimations {
            presentedViewController.view.frame = dismissedFrame
            self.updateProgressivePresentationController(progress: 0)
        }

        finishAnimator.addCompletion { _ in
            transitionContext.finishInteractiveTransition()
            transitionContext.completeTransition(true)
            self.interactionInProgress = false
        }

        finishAnimator.startAnimation()
    }
    
    private func updateProgressivePresentationController(progress: CGFloat) {
//        guard let presentedViewController = transitionContext?.viewController(forKey: .from),
//              let progressivePresentationController = presentedViewController.presentationController as? ProgressivePresentationController
//        else {
//            return
//        }
//        progressivePresentationController.update(progress: progress)
    }
}

extension PullToDismissInteractionController {
    @objc
    private func handleGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let superview = gestureRecognizer.view?.superview else { return }

        let translation = gestureRecognizer.translation(in: superview).y
        let velocity = gestureRecognizer.velocity(in: superview).y

        switch gestureRecognizer.state {
        case .began:
            gestureBegan()
        case .changed:
            gestureChanged(translation: translation + interruptedTranslation, velocity: velocity)
        case .cancelled:
            gestureCancelled(translation: translation + interruptedTranslation, velocity: velocity)
        case .ended:
            gestureEnded(translation: translation + interruptedTranslation, velocity: velocity)
        default:
            break
        }
    }

    private func gestureBegan() {
        disableOtherTouches()
        cancellationAnimator?.stopAnimation(true)

        if let presentedFrame = presentedFrame, let viewController = viewController {
            interruptedTranslation = viewController.view.frame.minY - presentedFrame.minY
        }

        if !interactionInProgress {
            interactionInProgress = true
            viewController?.dismiss(animated: true)
        }
    }

    private func gestureChanged(translation: CGFloat, velocity: CGFloat) {
        var progress = interactionDistance == 0 ? 0 : (translation / interactionDistance)
        if progress < 0 { progress /= (1.0 + abs(progress * 20)) }
        update(progress: progress)
    }

    private func gestureCancelled(translation: CGFloat, velocity: CGFloat) {
        cancel(initialSpringVelocity: springVelocity(distanceToTravel: -translation, gestureVelocity: velocity))
    }

    private func gestureEnded(translation: CGFloat, velocity: CGFloat) {
        if velocity > 800 || (translation > interactionDistance / 2.0 && velocity > -800) {
            finish(initialSpringVelocity: springVelocity(distanceToTravel: interactionDistance - translation, gestureVelocity: velocity))
        } else {
            cancel(initialSpringVelocity: springVelocity(distanceToTravel: -translation, gestureVelocity: velocity))
        }
    }

    private func springVelocity(distanceToTravel: CGFloat, gestureVelocity: CGFloat) -> CGFloat {
        distanceToTravel == 0 ? 0 : gestureVelocity / distanceToTravel
    }

    private func disableOtherTouches() {
        interactionEnabledViews = (viewController?.view.subviews ?? []).filter { $0.isUserInteractionEnabled }
        interactionEnabledViews.forEach {
            $0.isUserInteractionEnabled = false
        }
    }

    private func enableOtherTouches() {
        interactionEnabledViews.forEach {
            $0.isUserInteractionEnabled = true
        }
    }
}

extension PullToDismissInteractionController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let scrollView = activeScrollView,
              let panGesture = gestureRecognizer as? UIPanGestureRecognizer,
              let superview = gestureRecognizer.view?.superview else {
            return false
        }
        
        return scrollView.contentOffset.y <= 0 && panGesture.velocity(in: superview).y > 0
    }
}

