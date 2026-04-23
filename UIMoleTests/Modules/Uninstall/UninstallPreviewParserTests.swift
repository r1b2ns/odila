import Foundation
import Testing
@testable import UIMole

struct UninstallPreviewParserTests {

    /// Real mole --dry-run output (trimmed) with ANSI color escapes preserved.
    private static let sample = """
    \u{001B}[0;33m→ DRY RUN MODE\u{001B}[0m, No app files or settings will be modified

    \u{001B}[1;34m◎\u{001B}[0m Matched 1 app(s):
    1. AppCleaner  7.9MB  |  Last: 2m ago

    Proceed with uninstallation? [y/N]\u{0020}
    \u{001B}[1;35mFiles to be removed:\u{001B}[0m

    \u{001B}[1;34m◎\u{001B}[0m AppCleaner \u{001B}[0;90m, 8.0MB\u{001B}[0m
      \u{001B}[0;32m✓\u{001B}[0m /Applications/AppCleaner.app
      \u{001B}[0;32m✓\u{001B}[0m ~/Library/HTTPStorages/net.freemacsoft.AppCleaner
      \u{001B}[0;32m✓\u{001B}[0m ~/Library/Preferences/net.freemacsoft.AppCleaner.plist

    \u{001B}[0;35m➤\u{001B}[0m Remove 1 app, 8.0MB  \u{001B}[0;32mEnter\u{001B}[0m confirm
      \u{001B}[0;33m◎\u{001B}[0m Could not remove: ~/Library/HTTPStorages/net.freemacsoft.AppCleaner

    Uninstall dry run complete
    Would remove 1 app, would free \u{001B}[0;32m7.9MB\u{001B}[0m: \u{001B}[0;32mAppCleaner\u{001B}[0m
    """

    @Test
    func parsesAppNameSizeAndPaths() throws {
        let result = UninstallPreviewParser.parse(Self.sample)

        #expect(result.plans.count == 1)
        let plan = try #require(result.plans.first)
        #expect(plan.name == "AppCleaner")
        #expect(plan.size == "8.0MB")
        #expect(plan.paths == [
            "/Applications/AppCleaner.app",
            "~/Library/HTTPStorages/net.freemacsoft.AppCleaner",
            "~/Library/Preferences/net.freemacsoft.AppCleaner.plist"
        ])
    }

    @Test
    func capturesSummaryLine() {
        let result = UninstallPreviewParser.parse(Self.sample)
        #expect(result.summary == "Would remove 1 app, would free 7.9MB: AppCleaner")
    }

    @Test
    func stripsANSIFromRawOutput() {
        let result = UninstallPreviewParser.parse(Self.sample)
        #expect(!result.rawOutput.contains("\u{001B}["))
    }

    @Test
    func parsesMultipleApps() {
        let input = """
        ◎ Alpha, 10MB
          ✓ /Applications/Alpha.app
          ✓ ~/Library/Caches/com.alpha
        ◎ Beta , 5MB
          ✓ /Applications/Beta.app
        Would remove 2 apps, would free 15MB: Alpha, Beta
        """

        let result = UninstallPreviewParser.parse(input)

        #expect(result.plans.count == 2)
        #expect(result.plans[0].name == "Alpha")
        #expect(result.plans[0].paths.count == 2)
        #expect(result.plans[1].name == "Beta")
        #expect(result.plans[1].size == "5MB")
        #expect(result.plans[1].paths == ["/Applications/Beta.app"])
    }

    @Test
    func ignoresCouldNotRemoveLines() {
        let input = """
        ◎ Alpha, 10MB
          ✓ /Applications/Alpha.app
          ◎ Could not remove: ~/Library/Preferences/com.alpha.plist
        """

        let result = UninstallPreviewParser.parse(input)

        #expect(result.plans.count == 1)
        #expect(result.plans.first?.paths == ["/Applications/Alpha.app"])
    }

    @Test
    func unparseableOutputKeepsRawFallback() {
        let input = "no structured content here"
        let result = UninstallPreviewParser.parse(input)

        #expect(result.isEmpty)
        #expect(result.rawOutput == input)
    }
}
