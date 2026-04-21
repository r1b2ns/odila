import SwiftUI

struct StatusView<ViewModel: StatusViewModel>: View {

    @State var viewModel: ViewModel

    var body: some View {
        Group {
            if let snapshot = viewModel.snapshot {
                snapshotContent(snapshot)
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView(
                    "Failed to read status",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else {
                ProgressView("Collecting metrics…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 820, minHeight: 620)
        .navigationTitle("Status")
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    @ViewBuilder
    private func snapshotContent(_ snapshot: StatusSnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                StatusHeaderView(snapshot: snapshot)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ],
                    spacing: 16
                ) {
                    CPUSectionView(cpu: snapshot.cpu)
                    MemorySectionView(memory: snapshot.memory)
                    DiskSectionView(disks: snapshot.disks, io: snapshot.diskIo)
                    PowerSectionView(
                        batteries: snapshot.batteries,
                        thermal: snapshot.thermal
                    )
                    ProcessesSectionView(processes: snapshot.topProcesses)
                    NetworkSectionView(
                        interfaces: snapshot.network,
                        proxy: snapshot.proxy
                    )
                }
            }
            .padding(20)
        }
    }
}
