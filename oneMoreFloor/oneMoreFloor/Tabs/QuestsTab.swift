// QuestsTab.swift
// The Quests tab: daily quests and the all-complete bonus.

import SwiftUI

// MARK: - Quests Tab

struct QuestsTabView: View {
    let game: DungeonGame

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack {
                    Text("DAILY QUESTS")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.65))
                    Spacer()
                    Text("Resets at midnight")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.45))
                }
                .padding(.horizontal, 4)

                ForEach(game.dailyQuests) { quest in
                    QuestRowView(quest: quest) {
                        game.claimDailyQuest(id: quest.id)
                    }
                }

                if game.dailyQuests.isEmpty {
                    Text("No quests available.\nCheck back tomorrow.")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.35))
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 32)
                        .frame(maxWidth: .infinity)
                }

                if !game.dailyQuests.isEmpty {
                    DailyCompletionBonusView(
                        questCount: game.dailyQuests.count,
                        allClaimed: game.allQuestsClaimed,
                        bonusClaimed: game.dailyCompletionBonusClaimed
                    ) {
                        game.claimDailyCompletionBonus()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 32)
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.11))
    }
}

struct QuestRowView: View {
    let quest: DailyQuest
    let onClaim: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(quest.title)
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundStyle(quest.claimed ? Color.white.opacity(0.35) : .white)
                    Text(quest.description)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
                Spacer()
                Group {
                    if quest.claimed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color(red: 0.25, green: 0.75, blue: 0.40))
                    } else if quest.isComplete {
                        Button(action: onClaim) {
                            Text("+\(quest.rewardGold)g")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(red: 0.20, green: 0.55, blue: 0.25))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    } else {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(quest.progressLabel)
                                .font(.system(size: 12, weight: .medium, design: .monospaced).monospacedDigit())
                                .foregroundStyle(Color.white.opacity(0.55))
                            Text("+\(quest.rewardGold)g")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(Color.yellow.opacity(0.65))
                        }
                    }
                }
            }

            // Progress bar
            if !quest.claimed {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(white: 0.16))
                            .frame(height: 5)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(quest.isComplete
                                  ? Color(red: 0.25, green: 0.80, blue: 0.40)
                                  : Color(red: 0.35, green: 0.62, blue: 1.00))
                            .frame(width: geo.size.width * quest.progressFraction, height: 5)
                    }
                }
                .frame(height: 5)
                .animation(.easeOut(duration: 0.25), value: quest.progressFraction)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(quest.claimed ? Color(white: 0.07) : Color(white: 0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            quest.isComplete && !quest.claimed
                                ? Color(red: 0.25, green: 0.72, blue: 0.35).opacity(0.55)
                                : Color.white.opacity(0.07),
                            lineWidth: 1
                        )
                )
        )
    }
}

struct DailyCompletionBonusView: View {
    let questCount: Int
    let allClaimed: Bool
    let bonusClaimed: Bool
    let onClaim: () -> Void

    private let shards = DungeonGame.dailyCompletionBonusShards

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Daily Champion")
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundStyle(bonusClaimed ? Color.white.opacity(0.35) : .white)
                    Text("Complete all \(questCount) daily quests")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
                Spacer()
                Group {
                    if bonusClaimed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color(red: 0.25, green: 0.75, blue: 0.40))
                    } else if allClaimed {
                        Button(action: onClaim) {
                            Text("+\(shards) ◈")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(red: 0.55, green: 0.30, blue: 0.75))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("+\(shards) ◈")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.28))
                    }
                }
            }

            // Completion progress bar
            if !bonusClaimed {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(white: 0.16))
                            .frame(height: 5)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(allClaimed
                                  ? Color(red: 0.55, green: 0.30, blue: 0.75)
                                  : Color(red: 0.55, green: 0.30, blue: 0.75).opacity(0.45))
                            .frame(width: geo.size.width, height: 5)
                    }
                }
                .frame(height: 5)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(bonusClaimed ? Color(white: 0.07) : Color(white: 0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            allClaimed && !bonusClaimed
                                ? Color(red: 0.55, green: 0.30, blue: 0.75).opacity(0.65)
                                : Color.white.opacity(0.07),
                            lineWidth: 1
                        )
                )
        )
    }
}
