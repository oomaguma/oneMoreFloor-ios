// QuestsTab.swift
// The Quests tab: daily quests and the all-complete bonus.

import SwiftUI

// MARK: - Quests Tab

struct QuestsTabView: View {
    let game: DungeonGame

    /// Ready-to-claim first, then in-progress (closest to done first), claimed last —
    /// so the thing you can act on is always at the top.
    private var sortedQuests: [DailyQuest] {
        game.dailyQuests.sorted { a, b in
            func rank(_ q: DailyQuest) -> Int { q.claimed ? 2 : q.isComplete ? 0 : 1 }
            if rank(a) != rank(b) { return rank(a) < rank(b) }
            return a.progressFraction > b.progressFraction
        }
    }

    var body: some View {
        let claimable = game.dailyQuests.filter { $0.isComplete && !$0.claimed }.count
        let claimed   = game.dailyQuests.filter { $0.claimed }.count

        ScrollView {
            VStack(spacing: 10) {
                // Header: title + what's waiting for you.
                HStack(alignment: .firstTextBaseline) {
                    Text("QUESTS")
                        .font(Theme.Fonts.display(22))
                        .foregroundStyle(Theme.Palette.parchment)
                        .gameShadow()
                    Spacer()
                    if claimable > 0 {
                        Label("\(claimable) ready", systemImage: "gift.fill")
                            .font(Theme.Fonts.label(13))
                            .foregroundStyle(Theme.Palette.gold)
                    } else {
                        Label("Resets at midnight", systemImage: "clock")
                            .font(Theme.Fonts.label(12))
                            .foregroundStyle(Theme.Palette.dust)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 2)

                // The daily bonus sits up top as the goal everything feeds into.
                if !game.dailyQuests.isEmpty {
                    DailyCompletionBonusView(
                        questCount: game.dailyQuests.count,
                        claimedCount: claimed,
                        allClaimed: game.allQuestsClaimed,
                        bonusClaimed: game.dailyCompletionBonusClaimed
                    ) {
                        game.claimDailyCompletionBonus()
                    }
                }

                ForEach(sortedQuests) { quest in
                    QuestRowView(quest: quest) {
                        Haptics.impact(.medium)
                        SoundManager.shared.play("coin_collect")
                        game.claimDailyQuest(id: quest.id)
                    }
                }

                if game.dailyQuests.isEmpty {
                    Text("No quests available.\nCheck back tomorrow.")
                        .font(Theme.Fonts.body(13))
                        .foregroundStyle(Theme.Palette.dust)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 32)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 32)
            .animation(.spring(response: 0.4), value: game.dailyQuests.map(\.claimed))
        }
        .background(Theme.Palette.abyss)
    }
}

// MARK: - Quest Row

struct QuestRowView: View {
    let quest: DailyQuest
    let onClaim: () -> Void

    private var ready: Bool { quest.isComplete && !quest.claimed }

    var body: some View {
        HStack(spacing: 12) {
            // Icon tile per quest type, so the list scans at a glance.
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(style.color.opacity(quest.claimed ? 0.08 : 0.18))
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(style.color.opacity(quest.claimed ? 0.25 : 0.6), lineWidth: 1.5)
                Image(systemName: quest.claimed ? "checkmark" : style.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(quest.claimed ? Theme.Palette.life : style.color)
                    .gameShadow(1)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(quest.title)
                            .font(Theme.Fonts.label(16))
                            .foregroundStyle(Theme.Palette.parchment)
                        Text(quest.description)
                            .font(Theme.Fonts.body(13))
                            .foregroundStyle(Theme.Palette.dust)
                    }
                    Spacer(minLength: 6)
                    if !ready {
                        // In progress (or done): progress + the reward on offer.
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(quest.claimed ? "DONE" : quest.progressLabel)
                                .font(Theme.Fonts.number(13))
                                .foregroundStyle(quest.claimed ? Theme.Palette.life : Theme.Palette.parchment.opacity(0.8))
                            Label("\(quest.rewardGold)", systemImage: "circle.fill")
                                .font(Theme.Fonts.label(12))
                                .foregroundStyle(Theme.Palette.gold.opacity(quest.claimed ? 0.5 : 1))
                                .labelStyle(CoinLabelStyle())
                        }
                    }
                }
                if !quest.claimed && !ready {
                    GameBar(fraction: quest.progressFraction, color: Theme.Palette.gold,
                            height: 8, showsGhost: false)
                        .animation(.easeOut(duration: 0.25), value: quest.progressFraction)
                }
            }

            if ready {
                // Claim: a chunky gold coin button that gently pulses for attention.
                Button(action: onClaim) {
                    VStack(spacing: 0) {
                        Text("CLAIM").font(Theme.Fonts.label(10))
                        Label("\(quest.rewardGold)", systemImage: "circle.fill")
                            .font(Theme.Fonts.number(16))
                            .labelStyle(CoinLabelStyle())
                    }
                    .foregroundStyle(Color.black.opacity(0.8))
                }
                .buttonStyle(ChunkyButtonStyle(face: Theme.Palette.gold, lip: Theme.Palette.goldDeep,
                                               cornerRadius: 12, depth: 4))
                .frame(width: 84, height: 52)
                .phaseAnimator([1.0, 1.05]) { content, s in content.scaleEffect(s) }
                    animation: { _ in .easeInOut(duration: 0.7) }
            }
        }
        .padding(12)
        .gamePanel(tint: ready ? Theme.Palette.gold.opacity(0.8) : Theme.Palette.stoneEdge.opacity(0.6),
                   cornerRadius: 14)
        .shadow(color: ready ? Theme.Palette.gold.opacity(0.25) : .clear, radius: 10)
        .opacity(quest.claimed ? 0.6 : 1)
    }

    /// Icon + color per quest type.
    private var style: (icon: String, color: Color) {
        switch quest.type {
        case .killAny:     return ("bolt.fill", Theme.Palette.flame)
        case .killBoss:    return ("crown.fill", Theme.Palette.blood)
        case .earnGold:    return ("dollarsign.circle.fill", Theme.Palette.gold)
        case .clearFloors: return ("stairs", Theme.Palette.frost)
        case .reachFloor:  return ("flag.fill", Color(red: 0.75, green: 0.35, blue: 1.00))
        }
    }
}

/// A small coin dot before the number — compact enough for tight rows.
private struct CoinLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon.font(.system(size: 8, weight: .bold))
            configuration.title
        }
    }
}

// MARK: - Daily Champion bonus

struct DailyCompletionBonusView: View {
    let questCount: Int
    let claimedCount: Int
    let allClaimed: Bool
    let bonusClaimed: Bool
    let onClaim: () -> Void

    private let shards = DungeonGame.dailyCompletionBonusShards
    private let violet = Color(red: 0.70, green: 0.40, blue: 1.00)

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(violet.opacity(0.2))
                RoundedRectangle(cornerRadius: 10).strokeBorder(violet.opacity(0.7), lineWidth: 1.5)
                Image(systemName: bonusClaimed ? "checkmark" : "trophy.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(bonusClaimed ? Theme.Palette.life : violet)
                    .gameShadow(1)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily Champion")
                            .font(Theme.Fonts.label(16))
                            .foregroundStyle(Theme.Palette.parchment)
                        Text("Claim all \(questCount) quests today")
                            .font(Theme.Fonts.body(13))
                            .foregroundStyle(Theme.Palette.dust)
                    }
                    Spacer(minLength: 6)
                    if !(allClaimed && !bonusClaimed) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(bonusClaimed ? "DONE" : "\(claimedCount) / \(questCount)")
                                .font(Theme.Fonts.number(13))
                                .foregroundStyle(bonusClaimed ? Theme.Palette.life : Theme.Palette.parchment.opacity(0.8))
                            Text("+\(shards) ◈")
                                .font(Theme.Fonts.label(12))
                                .foregroundStyle(Theme.Palette.shard)
                        }
                    }
                }
                // Real progress: quests claimed so far (this used to draw full always).
                if !bonusClaimed && !allClaimed {
                    GameBar(fraction: Double(claimedCount) / Double(max(1, questCount)),
                            color: violet, height: 8, showsGhost: false)
                }
            }

            if allClaimed && !bonusClaimed {
                Button {
                    Haptics.notify(.success)
                    onClaim()
                } label: {
                    VStack(spacing: 0) {
                        Text("CLAIM").font(Theme.Fonts.label(10))
                        Text("+\(shards) ◈").font(Theme.Fonts.number(16))
                    }
                    .foregroundStyle(.white)
                    .gameShadow(1)
                }
                .buttonStyle(ChunkyButtonStyle(face: violet.mix(with: .black, by: 0.2),
                                               lip: violet.mix(with: .black, by: 0.7),
                                               cornerRadius: 12, depth: 4))
                .frame(width: 84, height: 52)
            }
        }
        .padding(12)
        .gamePanel(tint: violet.opacity(allClaimed && !bonusClaimed ? 0.9 : 0.5), cornerRadius: 14)
        .opacity(bonusClaimed ? 0.6 : 1)
    }
}
