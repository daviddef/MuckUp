import SwiftUI
import SwiftData

struct EventWrapUpView: View {
    @Bindable var event: MuckEvent
    @Environment(\.dismiss) private var dismiss
    @Query private var allMucks: [Muck]
    @EnvironmentObject var muckVM: MuckViewModel

    @State private var cardImage: UIImage?
    @State private var showShareSheet = false

    private var linkedMucks: [Muck] {
        allMucks.filter { event.muckIds.contains($0.id) }
    }

    private var clearedCount: Int {
        linkedMucks.filter { $0.isClosed }.count
    }

    private var estimatedKg: Int { event.bagCount * 3 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Impact card preview
                    ImpactCard(event: event, clearedCount: clearedCount, estimatedKg: estimatedKg)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                        .muckCardShadow()
                        .padding(.horizontal, Spacing.md)

                    // Stats breakdown
                    VStack(spacing: Spacing.xs) {
                        ImpactRow(icon: "bag.fill",          color: .muckGreen,  label: "Bags collected",   value: "\(event.bagCount)")
                        ImpactRow(icon: "scalemass.fill",    color: .muckAmber,  label: "Estimated weight", value: "\(estimatedKg) kg")
                        ImpactRow(icon: "person.2.fill",     color: .muckGreen,  label: "People on ground", value: "\(event.checkedInCount)")
                        ImpactRow(icon: "mappin.circle.fill",color: .muckAmber,  label: "Mucks cleared",    value: "\(clearedCount) of \(linkedMucks.count)")
                    }
                    .padding(.horizontal, Spacing.md)

                    // Share button
                    PrimaryButton(title: "Share Impact Card", icon: "square.and.arrow.up") {
                        renderAndShare()
                    }
                    .padding(.horizontal, Spacing.md)

                    // Council report prompt
                    Button {
                        // Future: generate PDF and open mail compose
                    } label: {
                        HStack {
                            Image(systemName: "doc.text.fill")
                            Text("Generate Council Report")
                        }
                        .font(.muckHeadline)
                        .foregroundStyle(Color.muckGreen)
                        .frame(maxWidth: .infinity)
                        .padding(Spacing.md)
                        .background(Color.muckGreen.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, Spacing.md)

                    Spacer(minLength: Spacing.xl)
                }
                .padding(.top, Spacing.md)
            }
            .background(Color.muckBg)
            .navigationTitle("Event Impact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        event.isLive = false
                        event.endedDate = .now
                        event.estimatedKg = Double(estimatedKg)
                        muckVM.award(.participate)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.muckGreen)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let img = cardImage {
                    ShareSheet(items: [img])
                }
            }
        }
    }

    private func renderAndShare() {
        let renderer = ImageRenderer(content:
            ImpactCard(event: event, clearedCount: clearedCount, estimatedKg: estimatedKg)
                .frame(width: 390, height: 390)
                .environment(\.colorScheme, .light)
        )
        renderer.scale = 3
        if let ui = renderer.uiImage {
            cardImage = ui
            event.impactCardData = ui.jpegData(compressionQuality: 0.85)
            showShareSheet = true
        }
    }
}

// MARK: - Impact Card (also renders to image)

struct ImpactCard: View {
    let event: MuckEvent
    let clearedCount: Int
    let estimatedKg: Int

    var body: some View {
        ZStack {
            Color.muckGreen

            VStack(spacing: 0) {
                // Top strip
                VStack(spacing: Spacing.xs) {
                    HStack {
                        Text("GRUB")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(.white.opacity(0.6))
                            .kerning(3)
                        Spacer()
                        Text("community cleanup")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.md)

                    Text(event.title)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.md)

                    Text(event.eventDate, style: .date)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                // Big number
                VStack(spacing: 2) {
                    Text("\(event.bagCount)")
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("bags of rubbish removed")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                // Bottom stats row
                HStack(spacing: 0) {
                    CardStat(value: "\(estimatedKg)kg", label: "removed")
                    CardStat(value: "\(event.checkedInCount)", label: "legends")
                    CardStat(value: "\(clearedCount)", label: "mucks cleared")
                }
                .padding(.bottom, Spacing.md)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct CardStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ImpactRow: View {
    let icon: String
    let color: Color
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(label)
                .font(.muckBody)
                .foregroundStyle(Color.muckNearBlack.opacity(0.6))
            Spacer()
            Text(value)
                .font(.muckHeadline)
                .foregroundStyle(Color.muckNearBlack)
        }
        .padding(Spacing.sm)
        .background(Color.muckSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
