import Foundation
import UIKit

final class ZopinSnapshotter {
    private let container: UIView
    private let isPresenting: Bool

    private var fromViews: [TransitioningView] = []
    private var fromSnapshots: [UIView] = []

    private var toViews: [TransitioningView] = []
    private var toSnapshots: [UIView] = []

    var groupedByDelays: [TimeInterval: [TransitioningView]] {
        return Dictionary(grouping: fromViews + toViews) { $0.config.relativeDelay }
    }

    var startDate = Date()

    init(fViews: [TransitioningView], fOverlayViews: [TransitioningView], tViews: [TransitioningView], tOverlayViews: [TransitioningView], container: UIView, isPresenting: Bool) {
        self.container = container
        self.isPresenting = isPresenting

        let fromTransitioningViews = extractViews(from: fViews, isFromView: true) + fOverlayViews
        let fromMovingViews = fromTransitioningViews
        let toTransitioningViews = extractViews(from: tViews, isFromView: false) + tOverlayViews
        let toMovingViews = toTransitioningViews

        print("ZopinTime: extractview: \(Date().timeIntervalSince1970 - startDate.timeIntervalSince1970)\n")
        startDate = Date()

        let sortedTransitioningViews = (fromMovingViews + toMovingViews).sorted(by: { $0.priority < $1.priority })
        let snapshots = createSnapshots(transitioningViews: sortedTransitioningViews)

        snapshots.forEach {
            container.addSubview($0)
        }

        sortedTransitioningViews.enumerated().forEach {
            guard let mask = $0.element.config.mask, let maskSnapshot = createSnapshot(transitioningView: mask) else { return }
            maskSnapshot.alpha = 1
            maskSnapshot.isHidden = false
            let snapshot = snapshots[$0.offset]
            snapshot.mask = maskSnapshot
        }

        print("ZopinTime: snapshot creation time: \(Date().timeIntervalSince1970 - startDate.timeIntervalSince1970)\n")
        startDate = Date()

        fromViews = sortedTransitioningViews.filter { fromMovingViews.contains($0) }
        fromSnapshots = snapshots.enumerated().filter({ (index, _) -> Bool in
            return fromViews.contains(sortedTransitioningViews[index])
        }).map { $0.element }
        positionFromSnapshots()

        print("ZopinTime: from view setup time: \(Date().timeIntervalSince1970 - startDate.timeIntervalSince1970)\n")
        startDate = Date()

        toViews = sortedTransitioningViews.filter { toMovingViews.contains($0) }
        toSnapshots = snapshots.enumerated().filter({ (index, _) -> Bool in
            return toViews.contains(sortedTransitioningViews[index])
        }).map { $0.element }
        positionToSnapshots()

        print("ZopinTime: end init time: \(Date().timeIntervalSince1970 - startDate.timeIntervalSince1970)\n")
        startDate = Date()
    }
}

extension ZopinSnapshotter {
    private func extractViews(from transitioningViews: [TransitioningView], isFromView: Bool) -> [TransitioningView] {
        var finalTransitioningViews = [TransitioningView]()
        for transitioningView in transitioningViews {
            let subviews = transitioningView.view.subviews.filter { String(describing: $0.classForCoder) != "_UIScrollViewScrollIndicator" }
            guard !subviews.isEmpty else {
                finalTransitioningViews.append(transitioningView)
                continue
            }

            if case .moveOut(let direction, let alphaChangeStrategy) = transitioningView.transitionStyle {
                finalTransitioningViews.append(
                    TransitioningView(view: transitioningView.view, transitionStyle: transitioningView.transitionStyle, priority: transitioningView.priority, config: TransitioningViewConfig(relativeDuration: transitioningView.config.relativeDuration, relativeDelay: transitioningView.config.relativeDelay, hideSubviews: true, mask: transitioningView.config.mask))
                )

                finalTransitioningViews.append(contentsOf:
                    extractSubviewsIfNeeded(
                        subviews: subviews,
                        baseTransitioningView: transitioningView,
                        isFromView: isFromView,
                        direction: direction,
                        alphaChangeStrategy: alphaChangeStrategy
                    )
                )

            } else if case .pageOut(let direction, let alphaChangeStrategy) = transitioningView.transitionStyle {
                finalTransitioningViews.append(
                    TransitioningView(view: transitioningView.view, transitionStyle: transitioningView.transitionStyle, priority: transitioningView.priority, config: TransitioningViewConfig(relativeDuration: transitioningView.config.relativeDuration, relativeDelay: transitioningView.config.relativeDelay, hideSubviews: true, mask: transitioningView.config.mask))
                )

                finalTransitioningViews.append(contentsOf:
                    extractSubviewsIfNeeded(
                        subviews: subviews,
                        baseTransitioningView: transitioningView,
                        isFromView: isFromView,
                        direction: direction,
                        alphaChangeStrategy: alphaChangeStrategy
                    )
                )

            } else if case .splitContent(let axis, let centerView, let keepCenterView, let alphaChangeStrategy) = transitioningView.transitionStyle {
                finalTransitioningViews.append(contentsOf:
                    extractSplitContentViews(
                        axis: axis,
                        subviews: subviews,
                        baseTransitioningView: transitioningView,
                        isFromView: isFromView,
                        centerView: centerView,
                        keepCenterView: keepCenterView,
                        alphaChangeStrategy: alphaChangeStrategy
                    )
                )
            } else {
                finalTransitioningViews.append(transitioningView)
            }
        }

        return finalTransitioningViews
    }

    private func extractSplitContentViews(axis: TranslationAxis, subviews: [UIView], baseTransitioningView: TransitioningView, isFromView: Bool, centerView: UIView, keepCenterView: Bool, alphaChangeStrategy: AlphaChangeStrategy) -> [TransitioningView] {
        var upLeftSubviews = [UIView]()
        var downRightSubviews = [UIView]()

        if axis == .vertical {
            upLeftSubviews = subviews.filter { $0.y < centerView.y }
            downRightSubviews = subviews.filter { $0.y > centerView.y }
        } else {
            upLeftSubviews = subviews.filter { $0.x < centerView.x }
            downRightSubviews = subviews.filter { $0.x > centerView.x }
        }

        baseTransitioningView.transitionStyle = .pageOut(direction: .up, alphaChangeStrategy: alphaChangeStrategy)
        let upLeftTransitioningViews = extractSubviewsIfNeeded(
            subviews: upLeftSubviews,
            baseTransitioningView: baseTransitioningView,
            isFromView: isFromView,
            direction: axis == .vertical ? .up : .left,
            alphaChangeStrategy: alphaChangeStrategy
        )

        baseTransitioningView.transitionStyle = .pageOut(direction: .down, alphaChangeStrategy: alphaChangeStrategy)
        let downRightTransitioningViews = extractSubviewsIfNeeded(
            subviews: downRightSubviews,
            baseTransitioningView: baseTransitioningView,
            isFromView: isFromView,
            direction: axis == .vertical ? .down : .right,
            alphaChangeStrategy: alphaChangeStrategy
        )

        let centerViews = subviews.filter { $0 === centerView && keepCenterView }.map {
            TransitioningView(
                view: $0,
                transitionStyle: .fade,
                priority: baseTransitioningView.priority,
                config: baseTransitioningView.config
            )
        }

        return upLeftTransitioningViews + downRightTransitioningViews + centerViews
    }

    private func extractSubviewsIfNeeded(subviews: [UIView], baseTransitioningView: TransitioningView, isFromView: Bool, direction: TranslationDirection, alphaChangeStrategy: AlphaChangeStrategy) -> [TransitioningView] {
        var orderedSubviews = subviews.sorted { (v1, v2) -> Bool in
            switch direction {
            case .left:
                return v1.x < v2.x
            case .right:
                return v1.x > v2.x
            case .up:
                return v1.y > v2.y
            case .down:
                return v1.y < v2.y
            }
        }

        if !isFromView {
            orderedSubviews.reverse()
        }

        var config = baseTransitioningView.config
        var delay = config.relativeDelay
        return orderedSubviews.map {
            config.relativeDelay = delay
            delay += alphaChangeStrategy.delay

            return TransitioningView(
                view: $0,
                transitionStyle: baseTransitioningView.transitionStyle,//.pageOut(direction: direction, alphaChangeStrategy: alphaChangeStrategy),
                priority: baseTransitioningView.priority,
                config: config
            )
        }
    }
}

// MARK: Helpers
extension ZopinSnapshotter {
    private func calculateViewOrigin(transitioningView: TransitioningView) -> CGPoint {
        let view = transitioningView.view
        guard let superview = view.superview else { return view.origin }
        return superview.convert(view.origin, to: container)
    }

    private func calculateViewContentOrigin(transitioningView: TransitioningView) -> CGPoint {
        if let collectionView = transitioningView.view as? UICollectionView, !collectionView.visibleCells.isEmpty { // Special case where you do not want to snapshot the empty offset
            return collectionViewMinYCellOrigin(collectionView: collectionView)
        } else if let scrollView = transitioningView.view as? UIScrollView, !scrollView.subviews.isEmpty {
            return scrollViewMinYViewOrigin(scrollView: scrollView)
        } else {
            return calculateViewOrigin(transitioningView: transitioningView)
        }
    }

    private func collectionViewMinYCellOrigin(collectionView: UICollectionView) -> CGPoint {
        let cells = collectionView.sortedByOriginCellSnapshots(afterScreenUpdates: true)
        let cellOrigins: [CGPoint] = cells.sorted(by: { $0.origin.y < $1.origin.y }).compactMap {
            return $0.origin
        }

        let minY = cellOrigins.min { $0.y < $1.y }?.y ?? 0
        return CGPoint(x: 0, y: minY)
    }

    private func scrollViewMinYViewOrigin(scrollView: UIScrollView) -> CGPoint {
        let subviews = scrollView.subviews.filter { String(describing: $0.classForCoder) != "_UIScrollViewScrollIndicator" }
        let origins: [CGPoint] = subviews.sorted(by: { $0.origin.y < $1.origin.y }).compactMap {
            return scrollView.convert($0.origin, to: scrollView.superview!)
        }
        let minY = origins.min { $0.y < $1.y }?.y ?? 0
        return CGPoint(x: 0, y: max(scrollView.y + scrollView.contentInset.top, minY))
    }

    private func createSnapshots(transitioningViews: [TransitioningView]) -> [UIView] {
        return transitioningViews.compactMap({ (transitioningView) -> UIView? in
            createSnapshot(transitioningView: transitioningView)
        })
    }

    private func createSnapshot(transitioningView: TransitioningView) -> UIView? {
        let view = transitioningView.view
        let shouldHideSubviews = transitioningView.config.hideSubviews
        return view.copyView(hideSubviews: shouldHideSubviews)
    }

    private func findToViewMatching(fromTransitioningView: TransitioningView) -> TransitioningView? {
        if case .match(let fromId, _) = fromTransitioningView.transitionStyle {
            return toViews.first(where: { (toTransitioningView) -> Bool in
                if case .match(let toId, _) = toTransitioningView.transitionStyle {
                    return fromId == toId
                }
                return false
            })
        }
        return nil
    }

    private func findRelatedView(to transitioningview: TransitioningView, in views: [TransitioningView]) -> TransitioningView? {
        switch transitioningview.transitionStyle {
        case .match(id: let id, _), .moveTo(id: let id, _):
            return views.first(where: { (view) -> Bool in
                guard transitioningview.transitionStyle.isSameStyle(as: view.transitionStyle) else { return false }

                switch view.transitionStyle {
                case .match(id: let viewId, _), .moveTo(id: let viewId, _):
                    return id == viewId
                default:
                    return false
                }
            })
        default:
            return nil
        }
    }
}

// MARK: Initial positioning
extension ZopinSnapshotter {
    private func positionFromSnapshots() {
        fromSnapshots.enumerated().forEach {
            let fromView = fromViews[$0.offset]
            let fromSnapshot = $0.element
            fromSnapshot.origin = calculateViewOrigin(transitioningView: fromView)
            positionFromSnapshotMaskIfNeeded(view: fromView, snapshot: fromSnapshot, views: fromViews)
        }
    }

    private func positionFromSnapshotMaskIfNeeded(view: TransitioningView, snapshot: UIView, views: [TransitioningView]) {
        guard let viewMask = view.config.mask, let maskIndex = views.firstIndex(of: viewMask), let maskSnapshot = snapshot.mask else { return }
        let maskOrigin = calculateViewOrigin(transitioningView: views[maskIndex])
        maskSnapshot.frame = CGRect(origin: container.convert(maskOrigin, to: snapshot), size: viewMask.view.size)
    }

    private func positionToSnapshots() {
        zip(toViews, toSnapshots).forEach { (toTransitioningView, toSnapshot) in
            toSnapshot.origin = toSnapshotOrigin(toTransitioningView: toTransitioningView, toSnapshot: toSnapshot)
            positionToSnapshotMaskIfNeeded(view: toTransitioningView, snapshot: toSnapshot, views: toViews)
        }
    }

    private func positionToSnapshotMaskIfNeeded(view: TransitioningView, snapshot: UIView, views: [TransitioningView]) {
        guard let viewMask = view.config.mask, let maskIndex = views.firstIndex(of: viewMask), let maskSnapshot = snapshot.mask else { return }
        let maskOrigin = toSnapshotOrigin(toTransitioningView: views[maskIndex], toSnapshot: toSnapshots[maskIndex])
        maskSnapshot.frame = CGRect(origin: container.convert(maskOrigin, to: snapshot), size: viewMask.view.size)
    }
}

// MARK: Initial appearance
extension ZopinSnapshotter {
    func setupViewsBeforeTransition() {
        setupMatchingViewsBeforeTransition()
        setupToMasks(views: toViews)
        setupViewsAppearanceBeforeTransition()
    }

    private func setupMatchingViewsBeforeTransition() {
        fromViews.forEach {
            if let matchingView = findToViewMatching(fromTransitioningView: $0), let fromIndex = fromViews.firstIndex(of: $0), let toIndex = toViews.firstIndex(of: matchingView) {
                let fromSnapshot = fromSnapshots[fromIndex]
                let toSnapshot = toSnapshots[toIndex]
                toSnapshot.cornerRadius = $0.view.cornerRadius
                toSnapshot.frame = fromSnapshot.frame
                //                toSnapshot.layer.shadowPath = UIBezierPath(rect: $0.view.bounds).cgPath
            }
        }
    }

    private func setupViewsAppearanceBeforeTransition() {
        zip(toViews, toSnapshots).forEach {
            $0.1.alpha = 1 - $0.0.alphaChange
        }
    }
}

// MARK: Final positioning
extension ZopinSnapshotter {
    private func toSnapshotOrigin(toTransitioningView: TransitioningView, toSnapshot: UIView) -> CGPoint {
        if case .moveOut(let direction, _) = toTransitioningView.transitionStyle {
            return toTransitioningViewMovingOutStartPoint(toSnapshot: toSnapshot, toTransitioningView: toTransitioningView, direction: direction)
        } else if case .pageOut(let direction, _) = toTransitioningView.transitionStyle {
            return toTransitioningViewMovingPageOutStartPoint(toSnapshot: toSnapshot, toTransitioningView: toTransitioningView, direction: direction)
        } else if let fromTransitioningView = findRelatedView(to: toTransitioningView, in: fromViews) {
            return calculateToMatchingViewOrigin(fromView: fromTransitioningView, toView: toTransitioningView)
        } else if case .moveWith(let parent, _) = toTransitioningView.transitionStyle {
            let position = calculateViewOrigin(transitioningView: toTransitioningView)
            guard let tuple = toFinalAppearancesViewTuple(transitioningView: parent), let parentIndex = toViews.firstIndex(of: parent) else { return position }
            let parentOrigin = toSnapshotOrigin(toTransitioningView: toViews[parentIndex], toSnapshot: toSnapshots[parentIndex])
            let parentFinalOrigin = calculateViewOrigin(transitioningView: tuple.0)
            let parentOriginDelta = CGPoint(x: parentFinalOrigin.x - parentOrigin.x, y: parentFinalOrigin.y - parentOrigin.y)

            return CGPoint(x: position.x - parentOriginDelta.x, y: position.y - parentOriginDelta.y)
        }

        return calculateViewOrigin(transitioningView: toTransitioningView)
    }

    private func calculateToMatchingViewOrigin(fromView: TransitioningView, toView: TransitioningView) -> CGPoint {
        let fromOrigin = calculateViewOrigin(transitioningView: fromView)
        let fromContentOrigin = calculateViewContentOrigin(transitioningView: fromView)

        let toOrigin = calculateViewOrigin(transitioningView: toView)
        let toContentOrigin = calculateViewContentOrigin(transitioningView: toView)
        let toDiff = toOrigin.y - toContentOrigin.y

        return CGPoint(x: fromOrigin.x, y: fromContentOrigin.y + toDiff)
    }

    private func toTransitioningViewMovingOutStartPoint(toSnapshot: UIView, toTransitioningView: TransitioningView, direction: TranslationDirection) -> CGPoint {
        var point = calculateViewOrigin(transitioningView: toTransitioningView)

        let extractedFromParent = toViews.filter { $0.view === toTransitioningView.view.superview && $0.transitionStyle.isSameStyle(as: toTransitioningView.transitionStyle) }.first?.view
        let isExtractedFromParent = extractedFromParent != nil

        let xParentDiff = isExtractedFromParent ? point.x - extractedFromParent!.x : 0
        let yParentDiff = isExtractedFromParent ? point.y - extractedFromParent!.y : 0

        switch direction {
        case .up:
            point.y = -toSnapshot.height - (isExtractedFromParent ? yParentDiff : 0)
        case .down:
            point.y = container.height + (isExtractedFromParent ? toSnapshot.y : 0)
        case .left:
            point.x = -toSnapshot.width - (isExtractedFromParent ? xParentDiff : 0)
        case .right:
            point.x = container.width + (isExtractedFromParent ? toSnapshot.x : 0)
        }

        return point
    }

    private func toTransitioningViewMovingPageOutStartPoint(toSnapshot: UIView, toTransitioningView: TransitioningView, direction: TranslationDirection) -> CGPoint {
        var point = calculateViewOrigin(transitioningView: toTransitioningView)
        let parentSize = toSnapshot.superview?.size ?? .zero

        switch direction {
        case .up:
            point.y -= parentSize.height
        case .down:
            point.y += parentSize.height
        case .left:
            point.x -= parentSize.width
        case .right:
            point.x += parentSize.width
        }

        return point
    }

    private func setupFromMaskFinalAppearances(views: [TransitioningView]) {
        let fViews = views.filter { fromViews.contains($0) }
        let fromViewsMasks = fromViews.map { $0.config.mask }

        fViews.forEach { view in
            guard let viewIndex = fromViews.firstIndex(of: view) else { return }
            let viewSnapshot = fromSnapshots[viewIndex]

            // Find where view is mask of one of the views
            let associatedMasksIndexes = fromViewsMasks.enumerated().compactMap { (index, mask) in
                return view === mask ? index : nil
            }

            associatedMasksIndexes.forEach { index in
                let maskParentSnapshot = fromSnapshots[index]
                guard let maskSnapshot = maskParentSnapshot.mask else { return }
                maskSnapshot.frame = CGRect(origin: container.convert(viewSnapshot.origin, to: maskParentSnapshot), size: viewSnapshot.size)
            }
        }
    }
}

// MARK: Final appearance
extension ZopinSnapshotter {
    func setupFromFinalAppearances(views: [TransitioningView]) {
        setupFromMatchingFinalAppearances(views: views)
        setupFromNotMatchingFinalAppearances(views: views)
        setupFromMaskFinalAppearances(views: views)
    }

    func setupViewsAfterTransition(isPresenting: Bool) {
        toSnapshots.forEach { $0.removeFromSuperview() }
        fromSnapshots.forEach { $0.removeFromSuperview() }
    }

    private func setupFromMatchingFinalAppearances(views: [TransitioningView]) {
        for fromView in views {
            guard let index = fromViews.firstIndex(of: fromView), let matchingToTransitioningView = findRelatedView(to: fromView, in: toViews) else { continue }
            let fromSnapshot = fromSnapshots[index]
            let startOrigin = fromSnapshot.origin

            if case .match(_, _) = matchingToTransitioningView.transitionStyle {
                fromSnapshot.cornerRadius = matchingToTransitioningView.view.cornerRadius
                fromSnapshot.alpha = 0
                let finalOrigin = calculateFromMatchingViewOrigin(fromView: fromView, toView: matchingToTransitioningView)
                fromSnapshot.frame = CGRect(origin: finalOrigin, size: matchingToTransitioningView.view.size)
                //                fromSnapshot.layer.shadowPath = UIBezierPath(rect: fromSnapshot.bounds).cgPath

                if let toIndex = toViews.firstIndex(of: matchingToTransitioningView) {
                    let toSnapshot = toSnapshots[toIndex]
                    toSnapshot.cornerRadius = matchingToTransitioningView.view.cornerRadius
                }

            } else if case .moveTo(_, _) = matchingToTransitioningView.transitionStyle {
                fromSnapshot.alpha = 0
                let finalOrigin = calculateFromMatchingViewOrigin(fromView: fromView, toView: matchingToTransitioningView)
                fromSnapshot.frame = CGRect(origin: finalOrigin, size: fromView.view.size)
                //                fromSnapshot.layer.shadowPath = UIBezierPath(rect: fromSnapshot.bounds).cgPath
            }

            let originDelta = CGPoint(x: fromSnapshot.x - startOrigin.x, y: fromSnapshot.y - startOrigin.y)
            setupMovingWithParentTransitioningViews(view: fromView, views: fromViews, snapshots: fromSnapshots, originDelta: originDelta)
        }
    }

    private func calculateFromMatchingViewOrigin(fromView: TransitioningView, toView: TransitioningView) -> CGPoint {
        let fromOrigin = calculateViewOrigin(transitioningView: fromView)
        let fromContentOrigin = calculateViewContentOrigin(transitioningView: fromView)

        let toOrigin = calculateViewOrigin(transitioningView: toView)
        let toContentOrigin = calculateViewContentOrigin(transitioningView: toView)

        let fromDiff = fromContentOrigin.y - fromOrigin.y
        return CGPoint(x: toOrigin.x, y: toContentOrigin.y - fromDiff)
    }

    private func setupFromNotMatchingFinalAppearances(views: [TransitioningView]) {
        for fromView in views {
            guard let index = fromViews.firstIndex(of: fromView) else { continue }
            var origin = calculateViewOrigin(transitioningView: fromView)
            let snapshot = fromSnapshots[index]
            let startOrigin = snapshot.origin
            let parentSize = snapshot.superview?.size ?? .zero

            let extractedFromParent = fromViews.filter { $0.view === fromView.view.superview && $0.transitionStyle.isSameStyle(as: fromView.transitionStyle) }.first?.view
            let isExtractedFromParent = extractedFromParent != nil

            let xParentDiff = isExtractedFromParent ? origin.x - extractedFromParent!.x : 0
            let yParentDiff = isExtractedFromParent ? origin.y - extractedFromParent!.y : 0

            if case .moveOut(let direction, let alphaChangeStrategy) = fromView.transitionStyle {
                switch direction {
                case .up:
                    origin.y -= snapshot.maxY - (isExtractedFromParent ? yParentDiff : 0)
                case .down:
                    origin.y += container.height - snapshot.y + (isExtractedFromParent ? yParentDiff : 0)
                case .left:
                    origin.x -= snapshot.maxX - (isExtractedFromParent ? xParentDiff : 0)
                case .right:
                    origin.x += container.width - snapshot.x + (isExtractedFromParent ? xParentDiff : 0)
                }

                snapshot.frame = CGRect(origin: origin, size: fromView.view.size)
                //                snapshot.layer.shadowPath = UIBezierPath(rect: snapshot.bounds).cgPath
                snapshot.alpha = 1 - alphaChangeStrategy.alphaChange

            } else if case .pageOut(let direction, let alphaChangeStrategy) = fromView.transitionStyle {
                switch direction {
                case .up:
                    origin.y -= parentSize.height
                case .down:
                    origin.y += parentSize.height
                case .left:
                    origin.x -= parentSize.width
                case .right:
                    origin.x += parentSize.width
                }

                snapshot.frame = CGRect(origin: origin, size: fromView.view.size)
                //                snapshot.layer.shadowPath = UIBezierPath(rect: snapshot.bounds).cgPath
                snapshot.alpha = 1 - alphaChangeStrategy.alphaChange

            } else if case .moveWith(_, let crossFades) = fromView.transitionStyle {
                // Origin move will be done by parent
                snapshot.alpha = crossFades ? 0 : 1
            } else if case .fade = fromView.transitionStyle {
                snapshot.alpha = 0
            }

            let originDelta = CGPoint(x: snapshot.x - startOrigin.x, y: snapshot.y - startOrigin.y)
            setupMovingWithParentTransitioningViews(view: fromView, views: fromViews, snapshots: fromSnapshots, originDelta: originDelta)
        }
    }

    private func setupMovingWithParentTransitioningViews(view: TransitioningView, views: [TransitioningView], snapshots: [UIView], originDelta: CGPoint) {
        views.enumerated().compactMap { (index, element) -> Int? in
            if case .moveWith(let parent, _) = element.transitionStyle {
                return view === parent ? index : nil
            }
            return nil
        }.forEach { index in
            let snapshot = snapshots[index]
            snapshot.origin = CGPoint(x: snapshot.x + originDelta.x, y: snapshot.y + originDelta.y)
        }
    }

    private func toFinalAppearancesViewTuple(transitioningView: TransitioningView) -> (TransitioningView, UIView)? {
        if let toView = findRelatedView(to: transitioningView, in: toViews), let toIndex = toViews.firstIndex(of: toView) {
            return (toView, toSnapshots[toIndex])
        } else if let toIndex = toViews.firstIndex(of: transitioningView) {
            switch transitioningView.transitionStyle {
            case .fade, .moveOut, .pageOut, .moveWith:
                return (transitioningView, toSnapshots[toIndex])
            default:
                return nil
            }
        }
        return nil
    }

    func setupToFinalAppearances(transitioningViews: [TransitioningView]) {
        for transitioningView in transitioningViews {
            guard let tuple = toFinalAppearancesViewTuple(transitioningView: transitioningView) else { continue }
            let finalTransitioningView = tuple.0
            let toSnapshot = tuple.1

            let origin: CGPoint = calculateViewOrigin(transitioningView: finalTransitioningView)
            var size: CGSize = finalTransitioningView.view.size

            if case .match(_, _) = finalTransitioningView.transitionStyle {
                size = finalTransitioningView.view.size
            }

            if case .moveTo(_, let crossFades) = finalTransitioningView.transitionStyle {
                toSnapshot.alpha = crossFades ? 1 : 0
            } else {
                toSnapshot.alpha = 1
            }

            toSnapshot.frame = CGRect(origin: origin, size: size)
            //            toSnapshot.layer.shadowPath = UIBezierPath(rect: toSnapshot.bounds).cgPath
        }

        setupToMasks(views: transitioningViews)
    }

    private func setupToMasks(views: [TransitioningView]) {
        let tViews = views.filter { toViews.contains($0) }
        let toViewsMasks = toViews.map { $0.config.mask }

        tViews.forEach { view in
            guard let viewIndex = toViews.firstIndex(of: view) else { return }
            let viewSnapshot = toSnapshots[viewIndex]

            // Find where view is mask of one of the toViews
            let associatedMasksIndexes = toViewsMasks.enumerated().compactMap { (index, mask) in
                return view === mask ? index : nil
            }

            associatedMasksIndexes.forEach { index in
                let maskParentSnapshot = toSnapshots[index]
                guard let maskSnapshot = maskParentSnapshot.mask else { return }
                maskSnapshot.frame = CGRect(origin: container.convert(viewSnapshot.origin, to: maskParentSnapshot), size: viewSnapshot.size)
            }
        }
    }
}
