import AppKit
import SwiftUI

struct RevealInFinderButton: View {
    let path: String

    var body: some View {
        Button {
            NSWorkspace.shared.selectFile(
                nil,
                inFileViewerRootedAtPath: path
            )
        } label: {
            Image(systemName: "arrow.up.forward.app")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Reveal in Finder")
    }
}
