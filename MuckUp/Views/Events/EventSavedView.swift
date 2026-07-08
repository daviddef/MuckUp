import SwiftUI

struct EventSavedView: View {
    var onBackToHome: () -> Void
    @State private var celebrate = false

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 72))
                .foregroundStyle(Color.muckGreen)
                .confettiBurst(trigger: $celebrate)
            Text("Event Scheduled!")
                .font(.muckDisplay)
                .foregroundStyle(Color.muckNearBlack)
            Text("+5 Muck Points earned")
                .font(.muckHeadline)
                .foregroundStyle(Color.muckAmber)
            Text("Confirmation and details will be sent to your registered email.")
                .font(.muckBody)
                .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
            Spacer()
            PrimaryButton(title: "Back to Home") {
                onBackToHome()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
        .background(Color.muckBg.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .onAppear { celebrate = true }
    }
}
