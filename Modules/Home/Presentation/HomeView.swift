import SwiftUI

struct HomeView<ViewModel: HomeViewModel>: View {

    let viewModel: ViewModel

    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 260), spacing: 20)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(viewModel.menuItems) { item in
                    if item.isEnabled {
                        NavigationLink(value: item.id) {
                            HomeMenuCard(item: item)
                        }
                        .buttonStyle(.plain)
                    } else {
                        HomeMenuCard(item: item)
                            .opacity(0.35)
                            .help("Coming soon")
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("UIMole")
        .frame(minWidth: 720, minHeight: 520)
    }
}

private struct HomeMenuCard: View {
    let item: HomeMenuItem

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 36, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
                .frame(height: 48)

            Text(item.title)
                .font(.headline)

            Text(item.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}
