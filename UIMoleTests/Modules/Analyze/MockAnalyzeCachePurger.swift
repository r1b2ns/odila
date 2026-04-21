import Foundation
@testable import UIMole

actor MockAnalyzeCachePurger: AnalyzeCachePurging {

    private(set) var callCount: Int = 0

    func purgeIfNeeded() async {
        callCount += 1
    }
}
