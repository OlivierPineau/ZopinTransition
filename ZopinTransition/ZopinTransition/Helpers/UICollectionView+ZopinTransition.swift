import Foundation
import UIKit

extension UICollectionView {
    func snapshotVisibleCells(afterScreenUpdates: Bool) -> UIView {
        let cellViews = sortedByOriginCellSnapshots(afterScreenUpdates: afterScreenUpdates)

        let minX = cellViews.min { $0.minX < $1.minX }?.minX ?? 0
        let maxX = cellViews.max { $0.maxX < $1.maxX }?.maxX ?? 0
        let minY = cellViews.min { $0.minY < $1.minY }?.minY ?? 0
        let maxY = cellViews.max { $0.maxY < $1.maxY }?.maxY ?? 0

        let xDiff = maxX - minX
        let finalWidth = max(width, xDiff)

        let yDiff = maxY - minY
        let finalHeight = max(height, yDiff)

        let backgroundViewSize = CGSize(width: finalWidth, height: finalHeight)
        let backgroundView = UIView(frame: CGRect(origin: .zero, size: backgroundViewSize))
        backgroundView.backgroundColor = backgroundColor

        cellViews.forEach {
            $0.origin.y -= minY
            backgroundView.addSubview($0)
        }

        return backgroundView
    }

    func sortedByOriginCellSnapshots(afterScreenUpdates: Bool) -> [UIView] {
        return subviews.filter { String(describing: $0.classForCoder) != "_UIScrollViewScrollIndicator" }
            .sorted(by: { $0.origin.y < $1.origin.y })
            .map {
                let cellView = $0.copyView(hideSubviews: false)
                cellView.origin = convert($0.origin, to: superview!)
                return cellView
            }
    }
}
