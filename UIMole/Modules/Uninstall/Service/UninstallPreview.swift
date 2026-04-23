import Foundation

/// A structured view of what `mo uninstall --dry-run` would do, parsed from the
/// CLI's human-readable output. Falls back to `rawOutput` when parsing can't
/// find any app sections (format drift).
struct UninstallPreview: Sendable, Equatable {

    let plans: [AppPlan]
    let summary: String?
    let rawOutput: String

    struct AppPlan: Sendable, Equatable, Identifiable {
        let name: String
        let size: String?
        let paths: [String]

        var id: String { name }
    }

    var isEmpty: Bool { plans.isEmpty }
}

enum UninstallPreviewParser {

    /// mole decorates the relevant lines with these markers:
    ///   `◎ <Name> , <Size>`    — app section header
    ///   `  ✓ <path>`           — individual path to remove
    ///   `Would remove N app…`  — trailing summary
    ///
    /// Lines like `◎ Could not remove: <path>` also start with `◎` but are not
    /// app headers — we filter them out explicitly.
    static func parse(_ output: String) -> UninstallPreview {
        let cleaned = stripANSI(output)

        var plans: [UninstallPreview.AppPlan] = []
        var currentName: String?
        var currentSize: String?
        var currentPaths: [String] = []
        var summary: String?

        func flush() {
            guard let name = currentName else { return }
            plans.append(
                UninstallPreview.AppPlan(
                    name: name,
                    size: currentSize,
                    paths: currentPaths
                )
            )
            currentName = nil
            currentSize = nil
            currentPaths = []
        }

        for rawLine in cleaned.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("◎ "),
               !trimmed.contains("Could not remove"),
               !trimmed.hasPrefix("◎ Matched"),
               let commaIdx = trimmed.lastIndex(of: ",") {
                flush()
                let nameRange = trimmed.index(trimmed.startIndex, offsetBy: 2)..<commaIdx
                let sizeStart = trimmed.index(after: commaIdx)
                currentName = trimmed[nameRange]
                    .trimmingCharacters(in: .whitespaces)
                let size = trimmed[sizeStart...]
                    .trimmingCharacters(in: .whitespaces)
                currentSize = size.isEmpty ? nil : size
                continue
            }

            if trimmed.hasPrefix("✓ "), currentName != nil {
                let path = String(trimmed.dropFirst(2))
                    .trimmingCharacters(in: .whitespaces)
                if !path.isEmpty {
                    currentPaths.append(path)
                }
                continue
            }

            if trimmed.hasPrefix("Would remove ") {
                summary = trimmed
                flush()
                continue
            }
        }
        flush()

        return UninstallPreview(
            plans: plans,
            summary: summary,
            rawOutput: cleaned
        )
    }

    static func stripANSI(_ text: String) -> String {
        text.replacingOccurrences(
            of: "\u{001B}\\[[0-9;]*[a-zA-Z]",
            with: "",
            options: .regularExpression
        )
    }
}
