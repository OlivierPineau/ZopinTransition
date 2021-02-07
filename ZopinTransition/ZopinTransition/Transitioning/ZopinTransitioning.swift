import Foundation
import MRGTaylor
import UIKit

public typealias TransitionableViewController = UIViewController & Transitionable
public typealias TransitionableView = UIView & Transitionable

@objc
public protocol Transitionable {
    func transitioningViews(forTransitionWith viewController: TransitionableViewController, isDestination: Bool) -> [TransitioningView]
}

public final class ZopinTransitioning: NSObject, UIViewControllerAnimatedTransitioning {
    private let duration: TimeInterval
    private let isPresenting: Bool
    private var hasInteractiveStart: Bool
    private let timingParameters: UITimingCurveProvider
    private var transitioningSnapshotter: ZopinSnapshotter?
    private var currentAnimator: UIViewImplicitlyAnimating?
    
    private var fromViews = [TransitioningView]()
    private var toViews = [TransitioningView]()
    private var fOverlayViews = [TransitioningView]()
    private var tOverlayViews = [TransitioningView]()
    private var overlaysOriginalAlpha = [CALayer: Float]()
    private var viewsOriginalAlpha = [CALayer: Float]()

    init(isPresenting: Bool, duration: TimeInterval = 0.35, timingParameters: UITimingCurveProvider = UICubicTimingParameters(animationCurve: .easeInOut), hasInteractiveStart: Bool = false) {
        self.isPresenting = isPresenting
        self.duration = duration
        self.timingParameters = timingParameters
        self.hasInteractiveStart = hasInteractiveStart
        super.init()
    }

    public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return duration
    }

    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        hasInteractiveStart = false
        prepareTransition(using: transitionContext)
        interruptibleAnimator(using: transitionContext).startAnimation()
    }
    
    public func interruptibleAnimator(using transitionContext: UIViewControllerContextTransitioning) -> UIViewImplicitlyAnimating {
        if let currentAnimator = currentAnimator {
            return currentAnimator
        }

        prepareTransition(using: transitionContext)
        
        guard !hasInteractiveStart, let animator = buildAnimator(using: transitionContext) else {
            return UIViewPropertyAnimator(duration: 0, curve: .linear, animations: nil)
        }
        self.currentAnimator = animator
        
        return animator
    }
    
    private func prepareTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let fromVc = transitionContext.viewController(forKey: .from),
              let fromViewController = findTransitionableViewController(from: fromVc),
              let toVc = transitionContext.viewController(forKey: .to),
              let toViewController = findTransitionableViewController(from: toVc)
        else {
            transitionContext.completeTransition(false)
            return
        }
        
        fromVc.beginAppearanceTransition(false, animated: true)
        toVc.beginAppearanceTransition(true, animated: true)

        setupContainer(context: transitionContext)
        
        fromViews = fromViewController.transitioningViews(forTransitionWith: toViewController, isDestination: false)
        toViews = toViewController.transitioningViews(forTransitionWith: fromViewController, isDestination: true)
        fOverlayViews = extractOverlayViews(viewController: fromVc)
        tOverlayViews = extractOverlayViews(viewController: toVc)
        overlaysOriginalAlpha = [CALayer: Float]()
        viewsOriginalAlpha = [CALayer: Float]()
        
        if isPresenting {
            fOverlayViews.flatMap { [$0.view] + $0.view.subviews }.map { $0.layer }.forEach { overlaysOriginalAlpha[$0] = $0.opacity }
            fromViews.flatMap { [$0.view] + $0.view.subviews }.map { $0.layer }.forEach { viewsOriginalAlpha[$0] = $0.opacity }
        } else {
            tOverlayViews.flatMap { [$0.view] + $0.view.subviews }.map { $0.layer }.forEach { overlaysOriginalAlpha[$0] = $0.opacity }
            toViews.flatMap { [$0.view] + $0.view.subviews }.map { $0.layer }.forEach { viewsOriginalAlpha[$0] = $0.opacity }
        }
    }
    
    func updateAnimator(using transitionContext: UIViewControllerContextTransitioning) {
        guard let animator = buildAnimator(using: transitionContext) else { return }
        self.currentAnimator = animator
        currentAnimator?.startAnimation()
    }
        
    private func buildAnimator(using transitionContext: UIViewControllerContextTransitioning) -> UIViewImplicitlyAnimating? {
        let container = transitionContext.containerView
        let snapshotter = ZopinSnapshotter(fViews: fromViews, fOverlayViews: fOverlayViews, tViews: toViews, tOverlayViews: tOverlayViews, container: container, isPresenting: isPresenting)
        self.transitioningSnapshotter = snapshotter
        
        if isPresenting {
            setupPresentationContainerAlpha(context: transitionContext)
        } else {
            setupDismissalContainerAlpha(context: transitionContext)
        }
        
        snapshotter.setupViewsBeforeTransition()

        if isPresenting {
            fOverlayViews.forEach { $0.view.alpha = 0 }
            fromViews.forEach { $0.view.alpha = 0 }
        } else {
            tOverlayViews.forEach { $0.view.alpha = 0 }
            toViews.forEach { $0.view.alpha = 0 }
        }
        
        let duration = transitionDuration(using: transitionContext)
        let animator = UIViewPropertyAnimator(duration: duration, timingParameters: timingParameters)

        let groupedByRelativeDelays = snapshotter.groupedByDelays
        let relativeDelays = groupedByRelativeDelays.keys.sorted { $0 < $1 }

        for relativeDelay in relativeDelays {
            guard let relativeDelayViewGroup = groupedByRelativeDelays[relativeDelay] else { continue }

            let groupedByRelativeDuration = Dictionary(grouping: relativeDelayViewGroup) { $0.config.relativeDuration }
            let durations = groupedByRelativeDuration.keys.sorted { $0 < $1 }

            for relativeDuration in durations {
                guard let views = groupedByRelativeDuration[relativeDuration] else { continue }
                animator.addAnimations({
                    snapshotter.setupToFinalAppearances(transitioningViews: views)
                    snapshotter.setupFromFinalAppearances(views: views)
                }, delayFactor: relativeDelay.f)
            }
        }

        animator.addCompletion { [weak self] (_) in
            self?.onTransitionEnded(using: transitionContext)
        }

        return animator
    }
    
    private func onTransitionEnded(using transitionContext: UIViewControllerContextTransitioning) {
        guard let snapshotter = transitioningSnapshotter,
              let fromVc = transitionContext.viewController(forKey: .from),
              let toVc = transitionContext.viewController(forKey: .to)
        else { return }
        
        snapshotter.setupViewsAfterTransition(isPresenting: isPresenting)

        if isPresenting {
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
        
        currentAnimator = nil
        transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
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
