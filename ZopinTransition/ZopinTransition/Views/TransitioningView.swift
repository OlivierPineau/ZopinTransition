import Foundation
import UIKit

@objc
public enum TranslationDirection: Int {
    case up, down, left, right
}

@objc
public enum TranslationAxis: Int {
    case vertical, horizontal
}

public enum AlphaChangeStrategy {
    case none
    case fade(alphaChange: CGFloat)
    case cascade(delay: TimeInterval, alphaChange: CGFloat)

    var delay: TimeInterval {
        switch self {
        case .cascade(let delay, _):
            return delay > 1 ? 1 : (delay < 0 ? 0 : delay)
        default:
            return 0
        }
    }

    var alphaChange: CGFloat {
        switch self {
        case .none:
            return 0
        case .fade(let alphaChange):
            return adjustAlphaChange(alphaChange: alphaChange)
        case .cascade(_, let alphaChange):
            return adjustAlphaChange(alphaChange: alphaChange)
        }
    }

    private func adjustAlphaChange(alphaChange: CGFloat) -> CGFloat {
        return alphaChange > 1 ? 1 : (alphaChange < 0 ? 0 : alphaChange)
    }
}

public enum TransitioningStyle {
    case keepOriginal
    case fade
    case moveWith(parent: TransitioningView, crossFades: Bool)
    case match(id: String, crossFades: Bool)
    case moveTo(id: String, crossFades: Bool)
    case moveOut(direction: TranslationDirection, alphaChangeStrategy: AlphaChangeStrategy)
    case pageOut(direction: TranslationDirection, alphaChangeStrategy: AlphaChangeStrategy)
    case splitContent(axis: TranslationAxis, centerView: UIView, keepCenterView: Bool, alphaChangeStrategy: AlphaChangeStrategy)

    func isSameStyle(as transitioningStyle: TransitioningStyle) -> Bool {
        switch (self, transitioningStyle) {
        case (.keepOriginal, .keepOriginal),
             (.fade, .fade),
             (.moveWith, .moveWith),
             (.match, .match),
             (.moveTo, .moveTo),
             (.moveOut, .moveOut),
             (.pageOut, .pageOut),
             (.splitContent, .splitContent):
            return true
        default:
            return false
        }
    }
}

public class TransitioningView: NSObject {
    var view: UIView
    var style: TransitioningStyle
    var priority: Int // 0 - Int.max
    var config: TransitioningViewConfig

    public init(view: UIView, style: TransitioningStyle, priority: Int, config: TransitioningViewConfig = TransitioningViewConfig()) {
        self.view = view
        self.style = style
        self.priority = max(priority, 0)
        self.config = config
        super.init()
    }
}

public extension TransitioningView {
    var alphaChange: CGFloat {
        switch style {
        case .moveWith(_, let crossFades),
             .match(_, let crossFades),
             .moveTo(_, let crossFades):
            return crossFades ? 1 : 0
        case .keepOriginal:
            return 0
        case .fade:
            return 1
        case .moveOut(_, let alphaChangeStrategy),
             .pageOut(_, let alphaChangeStrategy),
             .splitContent(_, _, _, let alphaChangeStrategy):
            return alphaChangeStrategy.alphaChange
        }
    }
    
    var originalAlphaChange: CGFloat {
        if case .keepOriginal = style {
            return 0
        } else {
            return 1
        }
    }
}

public struct TransitioningViewConfig {
    var relativeDuration: TimeInterval
    var relativeDelay: TimeInterval
    var hideSubviews: Bool
    var mask: TransitioningView?

    public init(relativeDuration: TimeInterval = 1, relativeDelay: TimeInterval = 0, hideSubviews: Bool = false, mask: TransitioningView? = nil) {
        self.relativeDuration = relativeDuration
        self.relativeDelay = relativeDelay
        self.hideSubviews = hideSubviews
        self.mask = mask
        calculateDurationAndDelay()
    }

    private mutating func calculateDurationAndDelay() {
        var tempDuration = relativeDuration < 0 ? 0 : (relativeDuration > 1 ? 1 : relativeDuration)
        let tempDelay = relativeDelay < 0 ? 0 : (relativeDelay > 1 ? 1 : relativeDelay)

        if tempDuration + tempDelay > 1 {
            tempDuration = 1 - tempDelay
        }

        self.relativeDuration = tempDuration
        self.relativeDelay = tempDelay
    }
}
