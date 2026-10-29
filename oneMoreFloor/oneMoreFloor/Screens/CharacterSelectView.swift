// CharacterSelectView.swift
// Character select: picking a class (and a dynasty heir) for a new run.

import SwiftUI
import SpriteKit

// MARK: - Character Select

struct DynastySelectContext {
    let retiringCharacterID: String
    let retiredCharacterIDs: [String]

    var retiringCharacterName: String {
        CharacterClass.all.first { $0.id == retiringCharacterID }?.name ?? "Hero"
    }
    // nil when the legacy for this character has already been claimed
    var pendingLegacyBonus: LegacyBonus? {
        guard !retiredCharacterIDs.contains(retiringCharacterID) else { return nil }
        return CharacterClass.all.first { $0.id == retiringCharacterID }?.legacyBonus
    }
}

struct CharacterSelectView: View {
    let onCancel: (() -> Void)?
    let onSelect: (CharacterClass) -> Void
    var dynastyContext: DynastySelectContext? = nil
    // True only for the title screen's "New Hero" flow, which really does wipe
    // the save. Mid-run hero swaps (Change Hero) keep every soul shard,
    // prestige upgrade, and deepest-floor record, so they get a reassuring
    // message instead of the data-loss warning.
    var isDestructiveReset: Bool = true

    init(onCancel: (() -> Void)? = nil,
         onSelect: @escaping (CharacterClass) -> Void,
         dynastyContext: DynastySelectContext? = nil,
         isDestructiveReset: Bool = true) {
        self.onCancel = onCancel
        self.onSelect = onSelect
        self.dynastyContext = dynastyContext
        self.isDestructiveReset = isDestructiveReset
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.11).ignoresSafeArea()

            VStack(spacing: 0) {
                Text(dynastyContext != nil ? "CHOOSE NEW CHAMPION" : "CHOOSE YOUR HERO")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.top, 52)
                    .padding(.bottom, 12)

                if let ctx = dynastyContext {
                    if let bonus = ctx.pendingLegacyBonus {
                        HStack(spacing: 6) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 11))
                            Text("Retiring \(ctx.retiringCharacterName): \(bonus.description)")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        }
                        .foregroundStyle(Color(red: 1.00, green: 0.80, blue: 0.25))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    } else {
                        Text("\(ctx.retiringCharacterName)'s legacy already claimed.")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.45))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    }
                } else if onCancel != nil && isDestructiveReset {
                    Text("Warning: starting a new hero resets all progress.")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(red: 1.00, green: 0.45, blue: 0.25))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                } else if onCancel != nil {
                    Text("Your soul shards and prestige upgrades carry over.")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                } else {
                    Spacer().frame(height: 8)
                }

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(CharacterClass.all) { character in
                            CharacterCardView(
                                character: character,
                                legacyBonusLabel: dynastyContext != nil ? character.legacyBonus.description : nil
                            ) {
                                onSelect(character)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }

            if let onCancel {
                VStack {
                    HStack {
                        Button(action: onCancel) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.60))
                                .padding(16)
                        }
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct CharacterCardView: View {
    let character: CharacterClass
    let onTap: () -> Void
    var legacyBonusLabel: String? = nil

    @State private var previewScene: IdlePreviewScene

    init(character: CharacterClass, legacyBonusLabel: String? = nil, onTap: @escaping () -> Void) {
        self.character = character
        self.legacyBonusLabel = legacyBonusLabel
        self.onTap = onTap
        _previewScene = State(initialValue: IdlePreviewScene(idleSpec: character.idle))
    }

    private var roleColor: Color {
        switch character.role {
        case "Tank", "Paladin": return Color(red: 0.35, green: 0.60, blue: 1.00)
        case "Warrior", "Duelist", "Skirmisher": return Color(red: 1.00, green: 0.45, blue: 0.25)
        case "Ranger": return Color(red: 0.30, green: 0.85, blue: 0.45)
        case "Mage": return Color(red: 0.80, green: 0.40, blue: 1.00)
        case "Healer": return Color(red: 0.95, green: 0.82, blue: 0.30)
        default: return .white
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                SpriteView(scene: previewScene, options: [.allowsTransparency])
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .clipped()

                HStack(alignment: .firstTextBaseline) {
                    Text(character.name)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    Text(character.role)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(roleColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(roleColor.opacity(0.15))
                        .clipShape(Capsule())
                }

                Text(character.description)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.60))
                    .fixedSize(horizontal: false, vertical: true)

                Divider().background(Color.white.opacity(0.10))

                HStack(spacing: 0) {
                    statPill("HP", "\(character.baseHP)", Color(red: 0.25, green: 0.85, blue: 0.40))
                    statPill("ATK", "\(character.baseATK)", Color(red: 1.00, green: 0.55, blue: 0.20))
                    statPill("DEF", "\(character.baseDEF)", Color(red: 0.35, green: 0.65, blue: 1.00))
                    if character.baseRegen > 0 {
                        statPill("RGN", "\(character.baseRegen)", Color(red: 0.95, green: 0.82, blue: 0.30))
                    }
                }

                if let bonus = legacyBonusLabel {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 9))
                        Text(bonus)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    }
                    .foregroundStyle(Color(red: 1.00, green: 0.75, blue: 0.15))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(roleColor.opacity(0.25), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func statPill(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.50))
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }
}
