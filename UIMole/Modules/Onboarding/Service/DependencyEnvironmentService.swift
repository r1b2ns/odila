import AppKit
import Foundation

enum DependencyStatus: Equatable, Sendable {
    case unknown
    case checking
    case installed(path: String)
    case missing
}

protocol DependencyEnvironmentService: Sendable {
    func checkBrew() async -> DependencyStatus
    func checkMole() async -> DependencyStatus
    func openInstallBrewInTerminal() throws
    func openInstallMoleInTerminal() throws
}

enum DependencyEnvironmentError: Error {
    case terminalLaunchFailed
}

final class DefaultDependencyEnvironmentService: DependencyEnvironmentService {

    private let executor: CommandExecuting

    init(executor: CommandExecuting = CommandExecutor()) {
        self.executor = executor
    }

    func checkBrew() async -> DependencyStatus {
        await locate(["/opt/homebrew/bin/brew", "/usr/local/bin/brew"], commandName: "brew")
    }

    func checkMole() async -> DependencyStatus {
        // The Mole CLI ships as `mo` (see https://github.com/tw93/Mole).
        await locate(
            [
                "/opt/homebrew/bin/mo",
                "/usr/local/bin/mo",
                "/opt/homebrew/bin/mole",
                "/usr/local/bin/mole"
            ],
            commandName: "mo"
        )
    }

    func openInstallBrewInTerminal() throws {
        // setup.sh is idempotent — installs whatever is missing — so the same
        // command serves both the brew and the mole install buttons.
        try runSetupScriptInTerminal()
    }

    func openInstallMoleInTerminal() throws {
        try runSetupScriptInTerminal()
    }

    private func runSetupScriptInTerminal(bundle: Bundle = .main) throws {
        guard let scriptURL = bundle.url(
            forResource: "setup",
            withExtension: "sh",
            subdirectory: "Scripts"
        ) else {
            throw DependencyEnvironmentError.terminalLaunchFailed
        }
        let escaped = scriptURL.path.replacingOccurrences(of: "\"", with: "\\\"")
        try runInTerminal("\"\(escaped)\"")
    }

    private func locate(_ paths: [String], commandName: String) async -> DependencyStatus {
        for path in paths where FileManager.default.isExecutableFile(atPath: path) {
            return .installed(path: path)
        }

        // Fallback: ask a login shell so user-level PATH additions are honored.
        if let resolved = try? await executor.execute(
            "/bin/zsh",
            arguments: ["-lc", "command -v \(commandName)"],
            currentDirectory: nil,
            environment: nil
        ), resolved.isSuccess {
            let trimmed = resolved.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return .installed(path: trimmed)
            }
        }
        return .missing
    }

    private func runInTerminal(_ command: String) throws {
        // Write the command to a temporary .command file and let Terminal run it.
        // This avoids the Apple Events entitlement that `tell application "Terminal"`
        // would otherwise require under hardened runtime.
        let script = """
        #!/bin/bash
        \(command)
        echo
        echo "[UIMole] Done. You can close this window."
        """

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("UIMole", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let scriptURL = directory.appendingPathComponent("install-\(UUID().uuidString).command")

        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: scriptURL.path
            )
        } catch {
            throw DependencyEnvironmentError.terminalLaunchFailed
        }

        let terminalURL = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.open(
            [scriptURL],
            withApplicationAt: terminalURL,
            configuration: configuration
        ) { _, _ in }
    }
}
