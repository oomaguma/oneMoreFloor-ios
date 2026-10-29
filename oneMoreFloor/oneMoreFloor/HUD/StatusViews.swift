// StatusViews.swift
// Small reusable status pieces: the status bar, combat status, health bar.

import SwiftUI

// MARK: - Status Bar

struct StatusBarView: View {
    let game: DungeonGame

    var body: some View {
        HStack(spacing: 0) {
            statCell(game.displayIsBoss ? "⚔ BOSS" : "STAGE", game.currentStageLabel)
            divider()
            statCell("GOLD", "\(game.gold)g")
            divider()
            statCell("SHARDS", "\(game.soulShards)")
        }
        .padding(.vertical, 10)
        .background(Color(white: 0.11))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.09), lineWidth: 1))
    }

    @ViewBuilder
    private func statCell(_ label: String, _ value: String, warning: Bool = false) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.75))
            Text(value)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundStyle(warning ? .red : .white)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private func divider() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(width: 1, height: 30)
    }
}

// MARK: - Combat Status

struct CombatStatusView: View {
    let game: DungeonGame

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(game.character.name.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.80))
                HealthBar(pct: heroPct, color: heroColor)
                Text("\(game.heroHp) / \(game.heroMaxHp)")
                    .font(.system(size: 13, design: .monospaced).weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.80))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 5) {
                Text(game.displayMonsterName.isEmpty ? "NO ENEMY" : game.displayMonsterName.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(game.displayIsBoss
                        ? Color(red: 1.0, green: 0.55, blue: 0.10)
                        : Color.white.opacity(0.80))
                if let status = game.bossStatusText {
                    Text(status)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(status == "SHIELDED"
                            ? Color(red: 0.45, green: 0.80, blue: 1.0)
                            : Color(red: 1.0, green: 0.40, blue: 0.32))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.08)))
                }
                HealthBar(pct: monsterPct, color: Color(red: 0.85, green: 0.22, blue: 0.22))
                Text(game.displayMonsterMaxHp > 0
                     ? "\(game.displayMonsterHp) / \(game.displayMonsterMaxHp)"
                     : "—")
                    .font(.system(size: 13, design: .monospaced).weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.80))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var heroPct: Double {
        guard game.heroMaxHp > 0 else { return 0 }
        return Double(max(0, game.heroHp)) / Double(game.heroMaxHp)
    }

    private var monsterPct: Double {
        guard game.displayMonsterMaxHp > 0 else { return 0 }
        return Double(max(0, game.displayMonsterHp)) / Double(game.displayMonsterMaxHp)
    }

    private var heroColor: Color {
        if heroPct > 0.5  { return Color(red: 0.25, green: 0.85, blue: 0.40) }
        if heroPct > 0.25 { return Color(red: 0.95, green: 0.78, blue: 0.18) }
        return Color(red: 0.90, green: 0.22, blue: 0.22)
    }
}

struct HealthBar: View {
    let pct: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(white: 0.16))
                    .frame(height: 10)
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: max(0, geo.size.width * pct), height: 10)
            }
        }
        .frame(height: 10)
        .animation(.easeOut(duration: 0.12), value: pct)
    }
}
