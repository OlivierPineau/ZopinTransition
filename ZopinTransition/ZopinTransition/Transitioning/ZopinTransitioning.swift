import Foundation
import MRGTaylor
import UIKit

typealias TransitionableViewController = UIViewController & Transitionable
typealias TransitionableView = UIView & Transitionable

@objc
protocol Transitionable {
    @objc optional func transitioningView(transitionableViewController: TransitionableViewController, isDestination: Bool) -> [TransitioningView]
}

final class ZopinTransitioning: NSObject, UIViewControllerAnimatedTransitioning, UIViewControllerInteractiveTransitioning {
    private let duration: TimeInterval
    private let isPresenting: Bool
    private var transitioningSnapshotter: ZopinSnapshotter!
    private var currentAnimator: UIViewImplicitlyAnimating?

    init(isPresenting: Bool, duration: TimeInterval = 0.35) {
        self.isPresenting = isPresenting
        self.duration = duration * 10
        super.init()
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return duration
    }

    var wantsInteractiveStart: Bool {
        return false
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        interruptibleAnimator(using: transitionContext).startAnimation()
    }

    func startInteractiveTransition(_ transitionContext: UIViewControllerContextTransitioning) {
        interruptibleAnimator(using: transitionContext).startAnimation()
    }

    func interruptibleAnimator(using transitionContext: UIViewControllerContextTransitioning) -> UIViewImplicitlyAnimating {
        if let currentAnimator = currentAnimator {
            return currentAnimator
        }

        guard let fromVc = transitionContext.viewController(forKey: .from),
            let fromViewController = findTransitionableViewController(from: fromVc),
            let toVc = transitionContext.viewController(forKey: .to),
            let toViewController = findTransitionableViewController(from: toVc)
        else {
            print("Failed to complete transition: \(self)")
            transitionContext.completeTransition(false)
            return UIViewPropertyAnimator(duration: 0, curve: .linear, animations: nil)
        }

        let container = transitionContext.containerView
        container.backgroundColor = .clear
        let duration = transitionDuration(using: transitionContext)

        if isPresenting {
            setupPresentationContainer(context: transitionContext)
        } else {
            setupDismissalContainer(context: transitionContext)
        }

        guard let fromViews = fromViewController.transitioningView?(transitionableViewController: toViewController, isDestination: false),
              let toViews = toViewController.transitioningView?(transitionableViewController: fromViewController, isDestination: true)
        else {
            print("Failed to complete transition: \(self)")
            transitionContext.completeTransition(false)
            return UIViewPropertyAnimator(duration: 0, curve: .linear, animations: nil)
        }

        let fOverlayViews = extractOverlayViews(viewController: fromVc)
        let tOverlayViews = extractOverlayViews(viewController: toVc)

        transitioningSnapshotter = ZopinSnapshotter(fViews: fromViews, fOverlayViews: fOverlayViews, tViews: toViews, tOverlayViews: tOverlayViews, container: container, isPresenting: isPresenting)
        transitioningSnapshotter.setupViewsBeforeTransition()

        if isPresenting {
            fromViews.forEach { $0.view.alpha = 0 }
        } else {
            toViews.forEach { $0.view.alpha = 0 }
        }

        let animator = UIViewPropertyAnimator(duration: duration, timingParameters: UICubicTimingParameters(animationCurve: .easeInOut))

        let groupedByRelativeDelays = transitioningSnapshotter.groupedByDelays
        let relativeDelays = groupedByRelativeDelays.keys.sorted { $0 < $1 }

        for relativeDelay in relativeDelays {
            guard let relativeDelayViewGroup = groupedByRelativeDelays[relativeDelay] else { continue }

            let groupedByRelativeDuration = Dictionary(grouping: relativeDelayViewGroup) { $0.config.relativeDuration }
            let durations = groupedByRelativeDuration.keys.sorted { $0 < $1 }

            for relativeDuration in durations {
                guard let views = groupedByRelativeDuration[relativeDuration] else { continue }

                print("adding anin, duration: \(relativeDuration) delay: \(relativeDelay)")

                animator.addAnimations({ [unowned self] in
                    self.transitioningSnapshotter.setupToFinalAppearances(transitioningViews: views)
                    self.transitioningSnapshotter.setupFromFinalAppearances(views: views)
                }, delayFactor: relativeDelay.f)
            }
        }

        animator.addCompletion { [weak self] (_) in
            guard let strongSelf = self else {
                transitionContext.completeTransition(true)
                return
            }
            
            strongSelf.transitioningSnapshotter.setupViewsAfterTransition(isPresenting: strongSelf.isPresenting)

            if strongSelf.isPresenting {
                fromViews.forEach { $0.view.alpha = 1 }
            } else {
                toViews.forEach { $0.view.alpha = 1 }
            }

            toVc.view.alpha = 1
            toVc.view.setNeedsLayout()
            toVc.view.layoutIfNeeded()
            strongSelf.currentAnimator = nil
            transitionContext.completeTransition(true)
        }

        self.currentAnimator = animator
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

    private func setupPresentationContainer(context: UIViewControllerContextTransitioning) {
        guard let toVc = context.viewController(forKey: .to) else { return }
        toVc.view.frame = context.finalFrame(for: toVc)
        context.containerView.addSubview(toVc.view)
        toVc.view.setNeedsLayout()
        toVc.view.layoutIfNeeded()

        toVc.view.alpha = 0
        context.containerView.layoutIfNeeded()
    }

    private func setupDismissalContainer(context: UIViewControllerContextTransitioning) {
        guard let fromVc = context.viewController(forKey: .from) else { return }
        fromVc.view.alpha = 0
    }

    private func extractOverlayViews(viewController: UIViewController) -> [TransitioningView] {
        var overlayViews = [TransitioningView]()
        if let navigationController = viewController as? UINavigationController {
            let navBar = navigationController.navigationBar
            overlayViews.append(
                TransitioningView(view: navBar, transitionStyle: .moveOut(direction: .up, alphaChangeStrategy: .none), priority: Int.max)
            )
        }

        if let tabBarVc = viewController as? UITabBarController {
            let tabBar = tabBarVc.tabBar
            overlayViews.append(
                TransitioningView(view: tabBar, transitionStyle: .moveOut(direction: .down, alphaChangeStrategy: .none), priority: Int.max)
            )
        }

        return overlayViews
    }
}