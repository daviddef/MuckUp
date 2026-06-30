import SwiftUI

struct TypeFilterBar: View {
    @Binding var selection: MuckType?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                FilterPill(title: "All", isActive: selection == nil) {
                    selection = nil
                }
                ForEach(MuckType.allCases, id: \.self) { type in
                    FilterPill(
                        title: type.displayName,
                        icon: type.icon,
                        isActive: selection == type,
                        activeColor: Color.muckTypeColor(type)
                    ) {
                        selection = (selection == type) ? nil : type
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }
}

struct FilterPill: View {
    let title: String
    var icon: String? = nil
    let isActive: Bool
    var activeColor: Color = .muckGreen
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xxs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .font(.muckCaption)
            }
            .foregroundStyle(isActive ? .white : .muckNearBlack)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xxs + 2)
            .background(isActive ? activeColor : Color.muckSurface)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isActive ? Color.clear : Color.muckNearBlack.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }
}

#Preview {
    @Previewable @State var filter: MuckType? = nil
    TypeFilterBar(selection: $filter)
        .padding(.vertical)
        .background(Color.muckBg)
}
