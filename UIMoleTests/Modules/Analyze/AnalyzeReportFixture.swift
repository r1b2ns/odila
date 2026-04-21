import Foundation
@testable import UIMole

extension AnalyzeReport {

    static func fixture(
        path: String = "/",
        entries: [Entry] = [
            Entry(
                name: "Xcode DerivedData",
                path: "/Users/test/Library/Developer/Xcode/DerivedData",
                size: 18_500_000_000,
                isDir: true,
                insight: true,
                cleanable: true
            ),
            Entry(
                name: "Old Downloads",
                path: "/Users/test/Downloads",
                size: -1,
                isDir: true,
                insight: true,
                cleanable: nil
            )
        ],
        totalSize: Int64 = 18_500_000_000
    ) -> AnalyzeReport {
        AnalyzeReport(
            path: path,
            overview: true,
            entries: entries,
            totalSize: totalSize
        )
    }
}
