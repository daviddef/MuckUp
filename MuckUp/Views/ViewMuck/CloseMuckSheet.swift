import SwiftUI

struct CloseMuckSheet: View {
    @Bindable var muck: Muck
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var muckVM: MuckViewModel

    @State private var afterPhotoData: Data?
    @State private var done = false

    var body: some View {
        NavigationStack {
            if done {
                VStack(spacing: Spacing.lg) {
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(Color.muckGreen)
                    Text("Muck Cleared!")
                        .font(.muckDisplay)
                        .foregroundStyle(Color.muckNearBlack)
                    Text("+10 Muck Points earned")
                        .font(.muckHeadline)
                        .foregroundStyle(Color.muckAmber)
                    Spacer()
                    PrimaryButton(title: "Done") { dismiss() }
                        .padding(.horizontal, Spacing.md)
                        .padding(.bottom, Spacing.xl)
                }
                .background(Color.muckBg.ignoresSafeArea())
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        // Before photo reminder
                        if let data = muck.photoData, let ui = UIImage(data: data) {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text("Before")
                                    .font(.muckCaption)
                                    .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 160)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                            }
                        }

                        // After photo capture
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("After — show the result")
                                .font(.muckTitle)
                                .foregroundStyle(Color.muckNearBlack)
                            Text("A photo of the cleared site creates a powerful before/after record for the community.")
                                .font(.muckBody)
                                .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                            PhotoPickerButton(
                                label: "Take an after photo",
                                systemImage: "camera.fill",
                                imageData: $afterPhotoData
                            )
                        }

                        PrimaryButton(title: "Mark as Cleaned Up", icon: "checkmark.seal") {
                            closeMuck()
                        }
                        .padding(.top, Spacing.xs)
                    }
                    .padding(Spacing.md)
                }
                .background(Color.muckBg)
                .navigationTitle("Close this Muck")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(Color.muckNearBlack)
                    }
                }
            }
        }
    }

    private func closeMuck() {
        muck.afterPhotoData = afterPhotoData
        muck.isClosed = true
        muck.closedDate = .now
        muckVM.award(.closeMuck)
        muckVM.recordClosed(muck.id)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { done = true }
    }
}
