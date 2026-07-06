import SwiftUI

/// Join-code based squads — a class, a family, a group of friends —
/// sharing one running point total plus a cross-squad leaderboard, so
/// contributing to the group's number is part of the fun, not just your
/// own personal rank.
struct SquadView: View {
    @EnvironmentObject var squadVM: SquadViewModel

    @State private var newSquadName = ""
    @State private var joinCode = ""
    @State private var showCreate = false
    @State private var showJoin = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if squadVM.isInSquad {
                    mySquadCard
                }

                if let error = squadVM.errorMessage {
                    Text(error)
                        .font(.muckCaption)
                        .foregroundStyle(Color.muckRed)
                }

                if !squadVM.isInSquad {
                    VStack(spacing: Spacing.sm) {
                        PrimaryButton(title: "Create a Squad", icon: "person.3.fill") {
                            showCreate = true
                        }
                        Button {
                            showJoin = true
                        } label: {
                            Text("Join with a code")
                                .font(.muckHeadline)
                                .foregroundStyle(Color.muckGreen)
                        }
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("🏆 Squad Leaderboard")
                        .font(.muckTitle)
                        .foregroundStyle(Color.muckNearBlack)

                    if squadVM.leaderboard.isEmpty {
                        Text("No squads yet — be the first to create one.")
                            .font(.muckBody)
                            .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                    } else {
                        ForEach(Array(squadVM.leaderboard.enumerated()), id: \.element.code) { index, squad in
                            HStack(spacing: Spacing.sm) {
                                Text("#\(index + 1)")
                                    .font(.muckCaption)
                                    .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                                    .frame(width: 28, alignment: .leading)
                                Text(squad.name)
                                    .font(.muckHeadline)
                                    .foregroundStyle(squad.code == squadVM.squadCode ? Color.muckGreen : Color.muckNearBlack)
                                Spacer()
                                Text("\(squad.totalPoints) pts")
                                    .font(.muckCaption)
                                    .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                            }
                            .padding(Spacing.sm)
                            .background(squad.code == squadVM.squadCode ? Color.muckGreen.opacity(0.08) : Color.muckSurface)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        }
                    }
                }
            }
            .padding(Spacing.md)
        }
        .background(Color.muckBg)
        .navigationTitle("Squad")
        .task {
            await squadVM.loadLeaderboard()
        }
        .alert("Create a Squad", isPresented: $showCreate) {
            TextField("Squad name", text: $newSquadName)
            Button("Create") {
                Task {
                    await squadVM.createSquad(name: newSquadName)
                    newSquadName = ""
                    await squadVM.loadLeaderboard()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Join a Squad", isPresented: $showJoin) {
            TextField("6-letter code", text: $joinCode)
                .textInputAutocapitalization(.characters)
            Button("Join") {
                Task {
                    await squadVM.joinSquad(code: joinCode)
                    joinCode = ""
                    await squadVM.loadLeaderboard()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var mySquadCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(squadVM.squadName ?? "Your Squad")
                        .font(.muckTitle)
                        .foregroundStyle(.white)
                    Text("Code: \(squadVM.squadCode ?? "—") · \(squadVM.memberCount) member\(squadVM.memberCount == 1 ? "" : "s")")
                        .font(.muckCaption)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                GrubCharacterView(mood: .celebrating, size: 44)
            }
            Text("\(squadVM.totalPoints) pts")
                .font(.muckDisplay)
                .foregroundStyle(.white)

            Button {
                squadVM.leaveSquad()
            } label: {
                Text("Leave squad")
                    .font(.muckCaption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(Spacing.md)
        .background(LinearGradient.muckGrowth)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
    }
}
