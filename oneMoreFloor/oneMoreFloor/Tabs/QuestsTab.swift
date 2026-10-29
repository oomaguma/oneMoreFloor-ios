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
                    Text("QUESTS")
                        .font(Theme.Fonts.display(22))
                        .foregroundStyle(Theme.Palette.parchment)
                        .gameShadow()
                    Spacer()
                    Text("Resets at midnight")
                        .font(Theme.Fonts.body(11))
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
                        .font(Theme.Fonts.body(13))
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
        .background(Theme.Palette.abyss)
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
                        .font(Theme.Fonts.body(15))
                        .foregroundStyle(quest.claimed ? Color.white.opacity(0.35) : .white)
                    Text(quest.description)
                        .font(Theme.Fonts.body(12))
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
                                .font(Theme.Fonts.label(14))
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
                                .font(Theme.Fonts.number(12))
                                .foregroundStyle(Color.white.opacity(0.55))
                            Text("+\(quest.rewardGold)g")
                                .font(Theme.Fonts.body(12))
                                .foregroundStyle(Color.yellow.opacity(0.65))
                        }
                    }
                }
            }

            // Progress bar
            if !quest.claimed {
                // Gold while in progress, green when done — the themed meter.
                GameBar(fraction: quest.progressFraction,
                        color: quest.isComplete ? Theme.Palette.life : Theme.Palette.gold,
                        height: 7, showsGhost: false)
                    .animation(.easeOut(duration: 0.25), value: quest.progressFraction)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(quest.claimed ? Theme.Palette.stone : Theme.Palette.stone)
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
                        .font(Theme.Fonts.body(15))
                        .foregroundStyle(bonusClaimed ? Color.white.opacity(0.35) : .white)
                    Text("Complete all \(questCount) daily quests")
                        .font(Theme.Fonts.body(12))
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
                                .font(Theme.Fonts.label(14))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(red: 0.55, green: 0.30, blue: 0.75))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("+\(shards) ◈")
                            .font(Theme.Fonts.body(10))
                            .foregroundStyle(Color.white.opacity(0.28))
                    }
                }
            }

            // Completion progress bar
            if !bonusClaimed {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Theme.Palette.stoneHi)
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
                .fill(bonusClaimed ? Theme.Palette.stone : Theme.Palette.stone)
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
