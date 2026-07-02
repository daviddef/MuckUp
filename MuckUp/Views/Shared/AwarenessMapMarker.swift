import SwiftUI

struct AwarenessMapMarker: View {
    let item: AwarenessItem

    private var color: Color {
        switch item.severity {
        case .warning: return .muckRed
        case .caution: return .muckAmber
        case .info:    return .muckGreen
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 30, height: 30)
            Image(systemName: item.category.icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
        }
        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
        .shadow(radius: 3)
    }
}

struct AwarenessDetailSheet: View {
    let item: AwarenessItem
    @Environment(\.dismiss) private var dismiss

    private var color: Color {
        switch item.severity {
        case .warning: return .muckRed
        case .caution: return .muckAmber
        case .info:    return .muckGreen
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Label(item.category.displayName, systemImage: item.category.icon)
                        .font(.muckCaption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .background(color)
                        .clipShape(Capsule())
                    Spacer()
                }

                Text(item.title)
                    .font(.muckDisplay)
                    .foregroundStyle(Color.muckNearBlack)

                Text(item.detail)
                    .font(.muckBody)
                    .foregroundStyle(Color.muckNearBlack.opacity(0.8))

                if let date = item.date {
                    Text("Last updated \(date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.muckCaption)
                        .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                }

                Spacer()
            }
            .padding(Spacing.md)
            .background(Color.muckBg)
            .navigationTitle("Area Awareness")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.muckNearBlack)
                }
            }
        }
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
    }
}
