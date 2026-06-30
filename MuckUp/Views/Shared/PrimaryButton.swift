import SwiftUI

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(.muckHeadline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(isDisabled ? Color.muckNearBlack.opacity(0.2) : Color.muckGreen)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
    }
}

struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(.muckHeadline)
            }
            .foregroundStyle(Color.muckGreen)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(Color.muckGreen.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .strokeBorder(Color.muckGreen.opacity(0.3), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 12) {
        PrimaryButton(title: "Raise a Muck", icon: "plus", action: {})
        PrimaryButton(title: "Disabled", isDisabled: true, action: {})
        SecondaryButton(title: "Schedule Event", icon: "calendar", action: {})
    }
    .padding()
}
