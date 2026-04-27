import SwiftUI

struct LicenseView: View {

    @Environment(\.dismiss) private var dismiss

    private let licenseText: String

    init(licenseText: String = LicenseView.loadBundledLicense()) {
        self.licenseText = licenseText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Label("License", systemImage: "doc.text")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)

            Divider()

            ScrollView {
                Text(licenseText)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
        }
        .frame(minWidth: 560, minHeight: 480)
    }

    static func loadBundledLicense(bundle: Bundle = .main) -> String {
        guard let url = bundle.url(forResource: "LICENSE", withExtension: "txt") else {
            return "LICENSE file not found in app bundle."
        }
        return (try? String(contentsOf: url, encoding: .utf8))
            ?? "LICENSE file is unreadable."
    }
}

#Preview {
    LicenseView(licenseText: "MIT License\n\nCopyright (c) 2026 Rubens")
}
