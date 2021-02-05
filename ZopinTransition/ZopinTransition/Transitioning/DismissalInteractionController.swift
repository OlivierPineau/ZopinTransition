import UIKit

public typealias InteractiveTransitionableViewController = TransitionableViewController & Interactive

public protocol Interactive {
    var initialDismissalScrollView: UIScrollView? { get }
}

public typealias InteractionControlling = UIViewControllerInteractiveTransitioning & InteractiveTransitioningController

public protocol InteractiveTransitioningController {
    var interactionInProgress: Bool { get }
}

protocol DismissalInteractionControllerDelegate: AnyObject {
    func willStartInteractiveTransition(with transitionContext: UIViewControllerContextTransitioning)
    func cancelInteractiveTransition(with initialSpringVelocity: CGFloat, _ transitionContext: UIViewControllerContextTransitioning)
    func finishInteractiveTransition(with initialSpringVelocity: CGFloat, _ transitionContext: UIViewControllerContextTransitioning)
}

class DismissalInteractionController: NSObject {
    weak var delegate: DismissalInteractionControllerDelegate?
    
    var interactionInProgress = false
    private weak var viewController: InteractiveTransitionableViewController!
    private weak var transitionContext: UIViewControllerContextTransitioning?

    private var verticalInteractionDistance: CGFloat = 0
    private var verticalInterruptedTranslation: CGFloat = 0
    private var horizontalInteractionDistance: CGFloat = 0
    private var horizontalInterruptedTranslation: CGFloat = 0
    
    private var presentedFrame: CGRect?
    private var cancellationAnimator: UIViewPropertyAnimator?
    
    enum TransitionType {
        case scaleCenter, dragAndScale
    }
    
    private let transitionType: TransitionType

    // MARK: - Setup
    init(viewController: InteractiveTransitionableViewController, transitionType: TransitionType) {
        self.viewController = viewController
        self.transitionType = transitionType
        super.init()
        prepareGestureRecognizer(in: viewController.view)
        if let scrollView = viewController.initialDismissalScrollView {
            resolveScrollViewGestures(scrollView)
        }
    }

    private func prepareGestureRecognizer(in view: UIView) {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(handleGesture(_:)))
        view.addGestureRecognizer(gesture)
    }

    private func resolveScrollViewGestures(_ scrollView: UIScrollView) {
        let scrollGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handleGesture(_:)))
        scrollGestureRecognizer.delegate = self

        scrollView.addGestureRecognizer(scrollGestureRecognizer)
        scrollView.panGestureRecognizer.require(toFail: scrollGestureRecognizer)
    }

    // MARK: - Gesture handling
    @objc func handleGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let superview = gestureRecognizer.view?.superview else { return }
        let velocity = gestureRecognizer.velocity(in: superview)
        let translation = gestureRecognizer.translation(in: superview)
        let adjustedTranslation = CGPoint(
            x: translation.x + horizontalInterruptedTranslation,
            y: translation.y + verticalInterruptedTranslation
        )
        
        switch gestureRecognizer.state {
        case .began:
            gestureBegan()
        case .changed:
            gestureChanged(translation: adjustedTranslation, velocity: velocity)
        case .cancelled:
            gestureCancelled(translation: adjustedTranslation, velocity: velocity)
        case .ended:
            gestureEnded(translation: adjustedTranslation, velocity: velocity)
        default:
            break
        }
    }

    private func gestureBegan() {
        disableOtherTouches()
        cancellationAnimator?.stopAnimation(true)

        if let presentedFrame = presentedFrame {
            horizontalInterruptedTranslation = viewController.view.frame.minX - presentedFrame.minX
            verticalInterruptedTranslation = viewController.view.frame.minY - presentedFrame.minY
        }

        if !interactionInProgress {
            interactionInProgress = true
            viewController.dismiss(animated: true)
        }
    }

    private func gestureCancelled(translation: CGPoint, velocity: CGPoint) {
        cancel(initialSpringVelocity: springVelocity(distanceToTravel: -translation.y, gestureVelocity: velocity.y))
    }

    private func gestureEnded(translation: CGPoint, velocity: CGPoint) {
        if velocity.y > 300 || (translation.y > verticalInteractionDistance / 2.0 && velocity.y > -300) {
            finish(initialSpringVelocity: springVelocity(distanceToTravel: verticalInteractionDistance - translation.y, gestureVelocity: velocity.y))
        } else {
            delegate?.finishInteractiveTransition(with: 0, transitionContext!)
//            cancel(initialSpringVelocity: springVelocity(distanceToTravel: -translation.y, gestureVelocity: velocity.y))
        }
    }
        
    private func gestureChanged(translation: CGPoint, velocity: CGPoint) {
        guard let transitionContext = transitionContext else { return }
        
//        var verticalProgress = verticalInteractionDistance == 0 ? 0 : (translation.y / verticalInteractionDistance)
//        if verticalProgress < 0 { verticalProgress /= (1.0 + abs(verticalProgress * 20)) }
        
//        transitionContext.updateInteractiveTransition(progress)
        
        switch transitionType {
        case .scaleCenter:
            updateScaleCenter(translation: translation, transitionContext: transitionContext)
        case .dragAndScale:
            updateDragAndScale(translation: translation, transitionContext: transitionContext)
//            let minScaleFactor: CGFloat = 0.85
//            let adjustedProgress = max(1 - progress, minScaleFactor)
//            let width = presentedFrame.width * adjustedProgress
//            let height = presentedFrame.height * adjustedProgress
            
//            presentedViewController.view.transform = .init(scaleX: adjustedProgress, y: adjustedProgress)
            
//            presentedViewController.view.frame = CGRect(
//                x: presentedFrame.midX - width / 2,
//                y: presentedFrame.midY - height / 2,
//                width: width,
//                height: height
//            )
//
//            presentedViewController.view.frame = CGRect(
//                x: presentedFrame.minX,
//                y: presentedFrame.minY + verticalInteractionDistance * progress,
//                width: presentedFrame.width,
//                height: presentedFrame.height
//            )
        }

//        if let modalPresentationController = presentedViewController.presentationController as? ModalPresentationController {
//            modalPresentationController.fadeView.alpha = 1.0 - progress
//        }
    }
    
    private func updateScaleCenter(translation: CGPoint, transitionContext: UIViewControllerContextTransitioning) {
        guard let presentedViewController = transitionContext.viewController(forKey: .from) else { return }
        let scaleTopMargin: CGFloat = 80
        let maxVerticalTranslation: CGFloat = presentedViewController.view.safeAreaInsets.top + scaleTopMargin
        
        let verticalTranslation = max(0, translation.y / 2)
        let adjustedTranslation = verticalInteractionDistance == 0 ? 0 : min(verticalTranslation, maxVerticalTranslation)
        let progress = adjustedTranslation / maxVerticalTranslation
        
        let viewCornerRadius: CGFloat = 20
        presentedViewController.view.layer.cornerRadius = viewCornerRadius * progress
        presentedViewController.view.clipsToBounds = true
        
        let scale = 1 - (maxVerticalTranslation / presentedViewController.view.height) * progress
        transitionContext.updateInteractiveTransition(scale)
        presentedViewController.view.transform = CGAffineTransform(scaleX: scale, y: scale)
    }
    
    private func updateDragAndScale(translation: CGPoint, transitionContext: UIViewControllerContextTransitioning) {
        guard let presentedViewController = transitionContext.viewController(forKey: .from) else { return }
        
        let maxHorizontalTranslation: CGFloat = 80
        let horizontalTranslation = max(0, translation.x)
        let adjustedHorizontalTranslation = horizontalInteractionDistance == 0 ? 0 : min(horizontalTranslation, maxHorizontalTranslation)
        let horizonalProgress = adjustedHorizontalTranslation / maxHorizontalTranslation
        
        let scaleTopMargin: CGFloat = 80
        let maxVerticalTranslation: CGFloat = presentedViewController.view.safeAreaInsets.top + scaleTopMargin
        let verticalTranslation = max(0, translation.y)
        let adjustedVerticalTranslation = verticalInteractionDistance == 0 ? 0 : min(verticalTranslation, maxVerticalTranslation)
        let verticalProgress = adjustedVerticalTranslation / maxVerticalTranslation
        
        let horizontalScale = 1 - (maxHorizontalTranslation / presentedViewController.view.width) * horizonalProgress
        let verticalScale = 1 - (maxVerticalTranslation / presentedViewController.view.height) * verticalProgress
        let scale = min(horizontalScale, verticalScale)
        transitionContext.updateInteractiveTransition(scale)
        
        let progress = scale == horizontalScale ? horizonalProgress : verticalProgress
        
        let viewCornerRadius: CGFloat = 20
        presentedViewController.view.layer.cornerRadius = viewCornerRadius * progress
        presentedViewController.view.clipsToBounds = true
        
        presentedViewController.view.transform = CGAffineTransform(
            scaleX: scale,
            y: scale
        ).concatenating(
            CGAffineTransform(
                translationX: translation.x,
                y: translation.y
            )
        )
    }
    
    func cancel(initialSpringVelocity: CGFloat) {
        guard let transitionContext = transitionContext,
              let presentedViewController = transitionContext.viewController(forKey: .from)
        else { return }

        let timingParameters = UISpringTimingParameters(dampingRatio: 0.8, initialVelocity: CGVector(dx: 0, dy: initialSpringVelocity))
        cancellationAnimator = UIViewPropertyAnimator(duration: 0.5, timingParameters: timingParameters)
        
        switch transitionType {
        case .scaleCenter, .dragAndScale:
            cancellationAnimator?.addAnimations {
                presentedViewController.view.transform = .identity
            }
            cancellationAnimator?.addCompletion { _ in
                transitionContext.cancelInteractiveTransition()
                transitionContext.completeTransition(false)
                self.interactionInProgress = false
                self.enableOtherTouches()
            }
            cancellationAnimator?.startAnimation()
//        default:
//            delegate?.cancelInteractiveTransition(with: initialSpringVelocity, transitionContext)
        }
    }

    func finish(initialSpringVelocity: CGFloat) {
        guard let transitionContext = transitionContext else { return }
        delegate?.finishInteractiveTransition(with: initialSpringVelocity, transitionContext)
//        guard let transitionContext = transitionContext, let presentedFrame = presentedFrame else { return }
//        let presentedViewController = transitionContext.viewController(forKey: .from) as! CustomPresentable
//        let dismissedFrame = CGRect(x: presentedFrame.minX, y: transitionContext.containerView.bounds.height, width: presentedFrame.width, height: presentedFrame.height)
//
//        let timingParameters = UISpringTimingParameters(dampingRatio: 0.8, initialVelocity: CGVector(dx: 0, dy: initialSpringVelocity))
//        let finishAnimator = UIViewPropertyAnimator(duration: 0.5, timingParameters: timingParameters)
//
//        finishAnimator.addAnimations {
//            presentedViewController.view.frame = dismissedFrame
//            if let modalPresentationController = presentedViewController.presentationController as? ModalPresentationController {
//                modalPresentationController.fadeView.alpha = 0.0
//            }
//        }
//
//        finishAnimator.addCompletion { _ in
//            transitionContext.finishInteractiveTransition()
//            transitionContext.completeTransition(true)
//            self.interactionInProgress = false
//        }
//
//        finishAnimator.startAnimation()
    }

    // MARK: - Helpers
    private func springVelocity(distanceToTravel: CGFloat, gestureVelocity: CGFloat) -> CGFloat {
        distanceToTravel == 0 ? 0 : gestureVelocity / distanceToTravel
    }

    private func disableOtherTouches() {
        viewController.view.subviews.forEach {
            $0.isUserInteractionEnabled = false
        }
    }

    private func enableOtherTouches() {
        viewController.view.subviews.forEach {
            $0.isUserInteractionEnabled = true
        }
    }
}

// MARK: - UIGestureRecognizerDelegate
extension DismissalInteractionController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let scrollView = viewController.initialDismissalScrollView {
            return scrollView.contentOffset.y <= 0
        }
        return true
    }
}

extension DismissalInteractionController: InteractionControlling {
    func startInteractiveTransition(_ transitionContext: UIViewControllerContextTransitioning) {
        guard let presentedViewController = transitionContext.viewController(forKey: .from) else {
            transitionContext.completeTransition(false)
            return
        }
    
        self.transitionContext = transitionContext
        delegate?.willStartInteractiveTransition(with: transitionContext)
        
        let finalFrame = transitionContext.finalFrame(for: presentedViewController)
        verticalInteractionDistance = transitionContext.containerView.bounds.height - finalFrame.minY
        horizontalInteractionDistance = transitionContext.containerView.bounds.width - finalFrame.minX
        
        presentedFrame = finalFrame
    }
    
    var wantsInteractiveStart: Bool {
        return true
    }
}
