import Foundation
import MRGTaylor
import UIKit

public typealias TransitionableViewController = UIViewController & Transitionable
public typealias TransitionableView = UIView & Transitionable

public typealias InteractiveTransitionableViewController = TransitionableViewController & Interactive

public protocol Interactive {
    var initialDismissalScrollView: UIScrollView? { get }
}

public typealias InteractionControlling = UIViewControllerInteractiveTransitioning & InteractiveTransitioningController

public protocol InteractiveTransitioningController {
    var interactionInProgress: Bool { get }
}

@objc
public protocol Transitionable {
    func transitioningViews(forTransitionWith viewController: TransitionableViewController, isDestination: Bool) -> [TransitioningView]
}

public final class ZopinTransitioning: NSObject, UIViewControllerAnimatedTransitioning, InteractionControlling {
    private let duration: TimeInterval
    private let isPresenting: Bool
    private let hasInteractiveStart: Bool
    private let timingParameters: UITimingCurveProvider
    private var currentAnimator: UIViewImplicitlyAnimating?
    
    private var viewController: InteractiveTransitionableViewController? {
        didSet {
            guard let viewController = viewController else { return }
            interactionController = PullToDismissInteractionController(viewController: viewController)
        }
    }
    private var interactionController: PullToDismissInteractionController?
    
    public var interactionInProgress: Bool {
        interactionController?.interactionInProgress == true
    }

    init(isPresenting: Bool, duration: TimeInterval = 0.35, timingParameters: UITimingCurveProvider = UICubicTimingParameters(animationCurve: .easeInOut), hasInteractiveStart: Bool = false, viewController: InteractiveTransitionableViewController? = nil) {
        self.isPresenting = isPresenting
        self.duration = duration
        self.timingParameters = timingParameters
        self.hasInteractiveStart = hasInteractiveStart
        self.viewController = viewController
        super.init()
    }

    public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return duration
    }

    public var wantsInteractiveStart: Bool {
        return hasInteractiveStart
    }

    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        interruptibleAnimator(using: transitionContext).startAnimation()
    }

    public func startInteractiveTransition(_ transitionContext: UIViewControllerContextTransitioning) {
        interruptibleAnimator(using: transitionContext).startAnimation()
    }

    public func interruptibleAnimator(using transitionContext: UIViewControllerContextTransitioning) -> UIViewImplicitlyAnimating {
        if let currentAnimator = currentAnimator {
            return currentAnimator
        }

        guard let fromVc = transitionContext.viewController(forKey: .from),
              let toVc = transitionContext.viewController(forKey: .to)
        else {
            transitionContext.completeTransition(false)
            return UIViewPropertyAnimator(duration: 0, curve: .linear, animations: nil)
        }
        
        fromVc.beginAppearanceTransition(false, animated: true)
        toVc.beginAppearanceTransition(true, animated: true)

        setupContainer(context: transitionContext)
        
        guard let animator = buildAnimator(using: transitionContext) else {
            return UIViewPropertyAnimator(duration: 0, curve: .linear, animations: nil)
        }
        self.currentAnimator = animator
        
        return animator
    }
    
    func updateAnimator(using transitionContext: UIViewControllerContextTransitioning) {
        guard let animator = buildAnimator(using: transitionContext) else { return }
        self.currentAnimator = animator
        currentAnimator?.startAnimation()
    }
        
    private func buildAnimator(using transitionContext: UIViewControllerContextTransitioning) -> UIViewImplicitlyAnimating? {
        guard let fromVc = transitionContext.viewController(forKey: .from),
            let fromViewController = findTransitionableViewController(from: fromVc),
            let toVc = transitionContext.viewController(forKey: .to),
            let toViewController = findTransitionableViewController(from: toVc)
        else {
            return nil
        }
        
        let fromViews = fromViewController.transitioningViews(forTransitionWith: toViewController, isDestination: false)
        let toViews = toViewController.transitioningViews(forTransitionWith: fromViewController, isDestination: true)

        let fOverlayViews = extractOverlayViews(viewController: fromVc)
        let tOverlayViews = extractOverlayViews(viewController: toVc)
        
        var overlaysOriginalAlpha = [CALayer: Float]()
        var viewsOriginalAlpha = [CALayer: Float]()
        if isPresenting {
            fOverlayViews.flatMap { [$0.view] + $0.view.subviews }.map { $0.layer }.forEach { overlaysOriginalAlpha[$0] = $0.opacity }
            fromViews.flatMap { [$0.view] + $0.view.subviews }.map { $0.layer }.forEach { viewsOriginalAlpha[$0] = $0.opacity }
        } else {
            tOverlayViews.flatMap { [$0.view] + $0.view.subviews }.map { $0.layer }.forEach { overlaysOriginalAlpha[$0] = $0.opacity }
            toViews.flatMap { [$0.view] + $0.view.subviews }.map { $0.layer }.forEach { viewsOriginalAlpha[$0] = $0.opacity }
        }
        
        let container = transitionContext.containerView
        let transitioningSnapshotter = ZopinSnapshotter(fViews: fromViews, fOverlayViews: fOverlayViews, tViews: toViews, tOverlayViews: tOverlayViews, container: container, isPresenting: isPresenting)
        
        if isPresenting {
            setupPresentationContainerAlpha(context: transitionContext)
        } else {
//            setupDismissalContainerAlpha(context: transitionContext)
        }
        
        transitioningSnapshotter.setupViewsBeforeTransition()

        if isPresenting {
            fOverlayViews.forEach { $0.view.alpha = 0 }
            fromViews.forEach { $0.view.alpha = 0 }
        } else {
            tOverlayViews.forEach { $0.view.alpha = 0 }
            toViews.forEach { $0.view.alpha = 0 }
        }
        
        let duration = transitionDuration(using: transitionContext)
        let animator = UIViewPropertyAnimator(duration: duration, timingParameters: timingParameters)

        let groupedByRelativeDelays = transitioningSnapshotter.groupedByDelays
        let relativeDelays = groupedByRelativeDelays.keys.sorted { $0 < $1 }

        for relativeDelay in relativeDelays {
            guard let relativeDelayViewGroup = groupedByRelativeDelays[relativeDelay] else { continue }

            let groupedByRelativeDuration = Dictionary(grouping: relativeDelayViewGroup) { $0.config.relativeDuration }
            let durations = groupedByRelativeDuration.keys.sorted { $0 < $1 }

            for relativeDuration in durations {
                guard let views = groupedByRelativeDuration[relativeDuration] else { continue }
                animator.addAnimations({
                    transitioningSnapshotter.setupToFinalAppearances(transitioningViews: views)
                    transitioningSnapshotter.setupFromFinalAppearances(views: views)
                }, delayFactor: relativeDelay.f)
            }
        }

        animator.addCompletion { [weak self] (_) in
            guard let strongSelf = self else {
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                return
            }
            
            transitioningSnapshotter.setupViewsAfterTransition(isPresenting: strongSelf.isPresenting)

            if strongSelf.isPresenting {
                fOverlayViews.flatMap { [$0.view] + $0.view.subviews }.map { $0.layer }.forEach { $0.opacity = overlaysOriginalAlpha[$0] ?? 1 }
                fromViews.flatMap { [$0.view] + $0.view.subviews }.map { $0.layer }.forEach { $0.opacity = viewsOriginalAlpha[$0] ?? 1 }
            } else {
                tOverlayViews.flatMap { [$0.view] + $0.view.subviews }.map { $0.layer }.forEach { $0.opacity = overlaysOriginalAlpha[$0] ?? 1 }
                toViews.flatMap { [$0.view] + $0.view.subviews }.map { $0.layer }.forEach { $0.opacity = viewsOriginalAlpha[$0] ?? 1 }
            }

            toVc.view.alpha = 1
            toVc.view.setNeedsLayout()
            toVc.view.layoutIfNeeded()
            
            fromVc.endAppearanceTransition()
            toVc.endAppearanceTransition()
            
            strongSelf.currentAnimator = nil
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }

        return animator
    }
}

extension ZopinTransitioning {
    private func findTransitionableViewController(from viewController: UIViewController) -> TransitionableViewController? {
        if let transitionableViewController = viewController as? TransitionableViewController {
            return transitionableViewController
        } else if let tabBarController = viewController as? UITabBarController, let selectedViewController = tabBarController.selectedViewController {
            return findTransitionableViewController(from: selectedViewController)
        } else if let navigationController = viewController as? UINavigationController, let topViewController = navigationController.topViewController {
            return findTransitionableViewController(from: topViewController)
        }

        return nil
    }

    private func findTransitionableView(from viewController: UIViewController) -> TransitionableView? {
        guard let viewControllerView = viewController.view else { return nil }
        return ZopinTransitioning.findTransitionableView(from: viewControllerView)
    }

    static func findTransitionableView(from view: UIView) -> TransitionableView? {
        if let transitionableView = view as? TransitionableView {
            return transitionableView
        }

        for subview in view.subviews {
            if let transitionableSubView = findTransitionableView(from: subview) {
                return transitionableSubView
            }
        }

        return nil
    }

    private func setupContainer(context: UIViewControllerContextTransitioning) {
        guard let toVc = context.viewController(forKey: .to) else { return }
        toVc.view.frame = context.finalFrame(for: toVc)
        context.containerView.insertSubview(toVc.view, at: 0)
        context.containerView.backgroundColor = .clear
        toVc.view.setNeedsLayout()
        toVc.view.layoutIfNeeded()
        toVc.view.setNeedsDisplay()
        context.containerView.layoutIfNeeded()
    }

    private func setupPresentationContainerAlpha(context: UIViewControllerContextTransitioning) {
        guard let toVc = context.viewController(forKey: .to) else { return }
        toVc.view.alpha = 0
    }
    
    private func setupDismissalContainerAlpha(context: UIViewControllerContextTransitioning) {
        guard let fromVc = context.viewController(forKey: .from) else { return }
        fromVc.view.alpha = 0
    }

    private func extractOverlayViews(viewController: UIViewController) -> [TransitioningView] {
        var overlayViews = [TransitioningView]()
        if let navigationController = viewController as? UINavigationController {
            let navBar = navigationController.navigationBar
            overlayViews.append(
                TransitioningView(view: navBar, style: .moveOut(direction: .up, alphaChangeStrategy: .none), priority: Int.max)
            )
        }

        if let tabBarVc = viewController as? UITabBarController {
            let tabBar = tabBarVc.tabBar
            overlayViews.append(
                TransitioningView(view: tabBar, style: .moveOut(direction: .down, alphaChangeStrategy: .none), priority: Int.max)
            )
        }

        return overlayViews
    }
}
