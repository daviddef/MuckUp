import SwiftUI

struct TypeBadgeView: View {
    let type: MuckType
    var compact: Bool = false

    var body: some View {
        HStack(spacing: Spacing.xxxs) {
            Image(systemName: type.icon)
                .font(.system(size: compact ? 9 : 11, weight: .semibold))
            if !compact {
                Text(type.displayName)
                    .font(.muckMicro)
            }
        }
        .foregroundStyle(Color.muckTypeColor(type))
        .padding(.horizontal, compact ? Spacing.xxs : Spacing.xs)
        .padding(.vertical, Spacing.xxxs + 1)
        .background(Color.muckTypeColor(type).opacity(0.12))
        .clipShape(Capsule())
    }
}

struct SourceBadgeView: View {
    let source: PartnerSource

    var body: some View {
        HStack(spacing: Spacing.xxxs) {
            Text(source.emoji)
                .font(.system(size: 9))
            Text(source.displayName)
                .font(.muckMicro)
        }
        .foregroundStyle(Color.partnerColor(source))
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.xxxs + 1)
        .background(Color.partnerColor(source).opacity(0.1))
        .clipShape(Capsule())
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        HStack {
            ForEach(MuckType.allCases, id: \.self) { TypeBadgeView(type: $0) }
        }
        HStack {
            ForEach(PartnerSource.allCases) { SourceBadgeView(source: $0) }
        }
    }
    .padding()
}
