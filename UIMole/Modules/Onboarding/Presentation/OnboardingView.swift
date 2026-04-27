import AppKit
import SwiftUI

struct OnboardingView<ViewModel: OnboardingViewModel>: View {

    @State var viewModel: ViewModel

    private var moleProjectURL: URL {
        URL(string: "https://github.com/tw93/Mole")!
    }

    var body: some View {
        VStack(spacing: 0) {
            stepIndicator
                .padding(.top, 24)
                .padding(.horizontal, 32)

            Group {
                switch viewModel.currentStep {
                case .welcome: welcomeStep
                case .about: aboutStep
                case .dependencies: dependenciesStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 32)

            footer
                .padding(20)
        }
        .frame(minWidth: 560, minHeight: 460)
    }

    // MARK: - Indicator

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingStep.allCases) { step in
                Capsule()
                    .fill(step.rawValue <= viewModel.currentStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(height: 4)
            }
        }
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Welcome to Mole")
                .font(.largeTitle).bold()
            Text("Let's get everything UIMole needs set up on your Mac.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    private var aboutStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer(minLength: 0)
            Image(systemName: "macwindow.on.rectangle")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("UIMole")
                .font(.largeTitle).bold()
            Text("UIMole is the graphical interface for Mole — a command-line tool that helps you uninstall and analyze macOS apps.")
                .font(.title3)
                .foregroundStyle(.secondary)
            Button {
                NSWorkspace.shared.open(moleProjectURL)
            } label: {
                Label("View Mole on GitHub", systemImage: "link")
            }
            .buttonStyle(.link)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dependenciesStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Requirements")
                .font(.largeTitle).bold()
            Text("UIMole depends on Homebrew and Mole. We'll check whether they're already installed — if anything is missing we'll open Terminal so you can finish the install.")
                .font(.callout)
                .foregroundStyle(.secondary)

            DependencyRow(
                title: "Homebrew",
                subtitle: "Package manager for macOS",
                status: viewModel.brewStatus,
                installAction: viewModel.installBrew
            )

            DependencyRow(
                title: "Mole",
                subtitle: "tw93/Mole CLI (mo command)",
                status: viewModel.moleStatus,
                installAction: viewModel.installMole,
                isDisabled: !brewIsInstalled
            )

            HStack {
                if viewModel.isCheckingDependencies {
                    ProgressView()
                        .controlSize(.small)
                }
                Button {
                    Task { await viewModel.refreshDependencies() }
                } label: {
                    Label("Check again", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isCheckingDependencies)
            }
            .padding(.top, 4)

            if let error = viewModel.lastError {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var brewIsInstalled: Bool {
        if case .installed = viewModel.brewStatus { return true }
        return false
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if viewModel.currentStep != .welcome {
                Button("Back") { viewModel.goBack() }
            }
            Spacer()
            if viewModel.isLastStep {
                Button("Finish") { viewModel.finish() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!viewModel.canFinish)
            } else {
                Button("Continue") { viewModel.advance() }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}

private struct DependencyRow: View {
    let title: String
    let subtitle: String
    let status: DependencyStatus
    let installAction: () -> Void
    var isDisabled: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            statusIcon
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if case .missing = status {
                Button("Install") { installAction() }
                    .disabled(isDisabled)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .unknown:
            Image(systemName: "questionmark.circle").foregroundStyle(.secondary)
        case .checking:
            ProgressView().controlSize(.small)
        case .installed:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .missing:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
    }

    private var detailText: String {
        switch status {
        case .unknown: return subtitle
        case .checking: return "Checking…"
        case .installed(let path): return path
        case .missing: return "Not found — \(subtitle)"
        }
    }
}
