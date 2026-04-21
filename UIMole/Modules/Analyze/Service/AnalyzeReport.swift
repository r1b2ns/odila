import Foundation

struct AnalyzeReport: Decodable, Sendable, Equatable {

    let path: String
    let overview: Bool
    let entries: [Entry]
    let totalSize: Int64

    struct Entry: Decodable, Sendable, Equatable, Identifiable {
        let name: String
        let path: String
        let size: Int64
        let isDir: Bool
        let insight: Bool?
        let cleanable: Bool?

        var id: String { path }

        /// `true` when the analyzer could not compute an exact size (sentinel `-1`).
        var hasUnknownSize: Bool { size < 0 }
    }
}
