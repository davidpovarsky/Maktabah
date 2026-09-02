import UIKit

extension ReaderViewModel {
    func jumpToPart(_ part: Int) {
        currentPart = max(1, part)
        currentPage = max(1, minPageInPart)
    }

    func jumpToPage(_ page: Int) {
        currentPage = max(minPageInPart, min(page, maxPageInPart))
    }
}

extension UIColor {
    func adjustBrightness(to targetBrightness: CGFloat) -> UIColor {
        self
    }
}
