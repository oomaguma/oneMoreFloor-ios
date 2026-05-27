import SwiftUI
import SpriteKit
import UIKit

// MARK: - Root (router)

struct ContentView: View {
    @State private var selectedCharacter: CharacterClass? = {
        if let id = DungeonGame.savedCharacterID() {
            return CharacterClass.all.first(where: { $0.id == id })
        }
        return nil
    }()
    @State private var previousCharacter: CharacterClass? = nil
    @State private var showTitle = true

    var body: some View {
        if showTitle {
            TitleScreenView(
                hasSave: selectedCharacter != nil,
                onContinue: {
                    withAnimation(.easeInOut(duration: 0.35)) { showTitle = false }
                },
                onNewHero: {
                    // Remember the saved hero (if any) so the player can cancel
                    // back to it; the save is only cleared once a new hero is
                    // actually chosen (handled in onSelect below).
                    previousCharacter = selectedCharacter
                    selectedCharacter = nil
                    withAnimation(.easeInOut(duration: 0.35)) { showTitle = false }
                }
            )
            .transition(.opacity)
        } else if let character = selectedCharacter {
            GameView(character: character) {
                previousCharacter = character
                selectedCharacter = nil
            }
        } else {
            CharacterSelectView(
                onCancel: previousCharacter != nil ? {
                    selectedCharacter = previousCharacter
                    previousCharacter = nil
                } : nil,
                onSelect: { newCharacter in
                    if previousCharacter != nil { DungeonGame.clearSave() }
                    selectedCharacter = newCharacter
                    previousCharacter = nil
                }
            )
        }
    }
}

// MARK: - Title Screen

struct TitleScreenView: View {
    let hasSave: Bool
    let onContinue: () -> Void
    let onNewHero: () -> Void

    @State private var pulse = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Pixel-art backdrop (crisp, no smoothing) filling the screen.
                Image("title_bg")
                    .resizable()
                    .interpolation(.none)
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                // Darken the bottom so the buttons stay legible.
                LinearGradient(colors: [.clear, .black.opacity(0.6)],
                               startPoint: .center, endPoint: .bottom)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Image("title_logo")
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(maxWidth: geo.size.width * 0.82)
                        .shadow(color: .black.opacity(0.55), radius: 0, x: 0, y: 3)
                        .padding(.top, max(48, geo.size.height * 0.09))
                        .background(
                            // Warm glow that gently breathes behind the logo/hero.
                            Circle()
                                .fill(Color(red: 1.0, green: 0.55, blue: 0.2))
                                .frame(width: 220, height: 220)
                                .blur(radius: 80)
                                .opacity(pulse ? 0.28 : 0.15)
                                .offset(y: geo.size.height * 0.10)
                        )

                    Spacer()

                    VStack(spacing: 14) {
                        if hasSave {
                            titleButton("CONTINUE",
                                        fill: Color(red: 0.62, green: 0.48, blue: 0.16),
                                        action: onContinue)
                        }
                        titleButton("NEW HERO",
                                    fill: Color(red: 0.18, green: 0.22, blue: 0.32),
                                    action: onNewHero)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, max(80, geo.size.height * 0.18))
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
        .preferredColorScheme(.dark)
    .ignoresSafeArea()
    }

    private func titleButton(_ label: String, fill: Color, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.impact(.medium)
            action()
        } label: {
            Text(label)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(fill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.22), lineWidth: 1.5)
                        )
                )
                .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
        }
    }
}

// MARK: - Character Select

struct CharacterSelectView: View {
    let onCancel: (() -> Void)?
    let onSelect: (CharacterClass) -> Void

    init(onCancel: (() -> Void)? = nil, onSelect: @escaping (CharacterClass) -> Void) {
        self.onCancel = onCancel
        self.onSelect = onSelect
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.11).ignoresSafeArea()

            VStack(spacing: 0) {
                Text("CHOOSE YOUR HERO")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.top, 52)
                    .padding(.bottom, onCancel == nil ? 20 : 12)

                // Only shown when swapping an existing hero (reached from the prestige tab),
                // where confirming a new pick wipes the current run's progress.
                if onCancel != nil {
                    Text("Warning: changing your hero resets all progress.")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(red: 1.00, green: 0.45, blue: 0.25))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(CharacterClass.all) { character in
                            CharacterCardView(character: character) {
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

    @State private var previewScene: IdlePreviewScene

    init(character: CharacterClass, onTap: @escaping () -> Void) {
        self.character = character
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

// MARK: - Game View

struct GameView: View {
    let character: CharacterClass
    let onChangeCharacter: () -> Void

    @State private var game: DungeonGame
    @State private var combatScene: CombatScene
    @State private var spriteOpacity    = 1.0
    @State private var isFading         = false
    @State private var offlineSummary: OfflineSummary?
    private let adManager               = AdManager.shared
    @State private var selectedTab: GameTab = .battle
    // true only after didEnterBackground fires; prevents spurious summaries from
    // temporary interruptions (phone calls, notification banners, control center)
    @State private var didEnterBackground = false
    @State private var showStore    = false
    @State private var showSettings = false

    init(character: CharacterClass, onChangeCharacter: @escaping () -> Void) {
        self.character = character
        self.onChangeCharacter = onChangeCharacter
        let g = DungeonGame(character: character)
        let initialEnemy = g.currentEnemyType ?? EnemyType.slime
        _game = State(initialValue: g)
        _combatScene = State(initialValue: CombatScene(hero: character, initialEnemy: initialEnemy, initialZoneID: g.currentZone.id))
    }

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.11)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    StatusBarView(game: game)
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.white.opacity(0.60))
                            .frame(width: 44, height: 44)
                            .background(Color(white: 0.11))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.09), lineWidth: 1))
                    }
                    Button { showStore = true } label: {
                        Image(systemName: "cart.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color(red: 1.00, green: 0.75, blue: 0.25).opacity(0.85))
                            .frame(width: 44, height: 44)
                            .background(Color(white: 0.11))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.09), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .sheet(isPresented: $showStore) { StoreSheetView() }
                .sheet(isPresented: $showSettings) { SettingsView() }

                BattleTabView(game: game, combatScene: combatScene, spriteOpacity: spriteOpacity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(red: 0.07, green: 0.07, blue: 0.11))

                CustomGameTabBar(selectedTab: $selectedTab, hasClaimableQuest: game.hasClaimableQuest)
            }

            if let drop = game.pendingDrop, game.pendingBossVictory == nil {
                VStack {
                    ItemDropBanner(item: drop, onDismiss: { game.dismissDrop() })
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    Spacer()
                }
                .animation(.spring(response: 0.4), value: game.pendingDrop?.id)
            }

            if game.isGameOver && !game.autoRestartEnabled {
                GameOverOverlay(
                    adManager: adManager,
                    onRevive: {
                        game.revive()
                        combatScene.playHeroIdle()
                        combatScene.playEnemyIdle()
                    },
                    onRestart: {
                        game.restart()
                        combatScene.playHeroIdle()
                        combatScene.playEnemyIdle()
                    }
                )
            }

            if let summary = offlineSummary {
                OfflineSummaryView(
                    summary: summary,
                    adManager: adManager,
                    onDoubleGold: { game.gold += summary.goldEarned },
                    onDismiss: { offlineSummary = nil }
                )
            }

            if let victory = game.pendingBossVictory {
                BossVictoryOverlay(victory: victory) { game.dismissBossVictory() }
            }

            if game.pendingBossVictory == nil, let zone = game.pendingZoneUnlock {
                ZoneUnlockOverlay(zone: zone) { game.dismissZoneUnlock() }
            }
        }
        .sheet(isPresented: showSheet) {
            sheetContent
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if let summary = game.handleForeground() {
                offlineSummary = summary
            }
            combatScene.updateZoneBackground(game.currentZone.id)
            if let enemy = game.currentEnemyType {
                combatScene.updateEnemy(enemy)
                combatScene.playEnemyIdle()
            }
            combatScene.playHeroIdle()

            game.onHeroAttack = {
                combatScene.playHeroAttack()
            }
            game.onHeroHurt = { combatScene.playHeroHurt() }
            game.onHeroDeath = {
                combatScene.playHeroDeath()
                SoundManager.shared.play("8_bit_defeated")
                Haptics.notify(.error)
            }
            game.onHeroBlock = {
                combatScene.playHeroBlock()
                Haptics.impact(.rigid)
            }
            game.onHeroCrit = { dmg in
                combatScene.showMonsterCritDamage(dmg)
                Haptics.impact(.heavy)
            }
            game.onHeroHeal = { amt in
                combatScene.showHeroHeal(amt)
                combatScene.playHeroHeal()
            }

            game.onMonsterSpawn  = { enemy in combatScene.updateEnemy(enemy); combatScene.playEnemyIdle() }
            game.onMonsterHurt   = { combatScene.playEnemyHurt() }
            game.onMonsterAttack = { combatScene.playEnemyAttack() }
            game.onMonsterDeath  = { combatScene.playEnemyDeath() }

            game.onHeroDamageTaken    = { dmg  in combatScene.showHeroDamage(dmg) }
            game.onMonsterDamageTaken = { dmg  in combatScene.showMonsterDamage(dmg) }
            game.onGoldEarned         = { gold in combatScene.showGoldReward(gold) }

            game.log("You descend into the dungeon...")
            game.log("Combat begins shortly.")
        }
        .onChange(of: game.pendingBossVictory != nil) { _, hasVictory in
            if hasVictory {
                SoundManager.shared.play("8_bit_positive_long")
                Haptics.notify(.success)
            }
        }
        .onChange(of: game.pendingZoneUnlock != nil) { _, hasUnlock in
            if hasUnlock { Haptics.notify(.success) }
        }
        .onChange(of: game.pendingDrop?.id) { _, newID in
            if newID != nil {
                SoundManager.shared.play("item_equip")
                Haptics.impact(.medium)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            // Save state on any inactivity (phone calls, banners, etc.) for crash safety.
            game.save()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            // Record that we truly entered background so the foreground handler can
            // distinguish a real background session from a brief interruption.
            didEnterBackground = true
            // Skip the "hero has fallen" notification for players who bought Remove Ads,
            // since they get a free revive and the character carries on automatically.
            if !StoreManager.shared.hasPurchasedRemoveAds,
               let seconds = game.estimatedSecondsUntilFirstDeath() {
                NotificationManager.shared.scheduleDeathNotification(in: seconds, characterName: game.character.name)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            NotificationManager.shared.cancelDeathNotification()
            // Only run offline simulation when returning from a true background session.
            if didEnterBackground {
                didEnterBackground = false
                if let summary = game.handleForeground() {
                    offlineSummary = summary
                }
            }
            combatScene.updateZoneBackground(game.currentZone.id)
            if let enemy = game.currentEnemyType {
                combatScene.updateEnemy(enemy)
                combatScene.playEnemyIdle()
            }
            combatScene.playHeroIdle()
        }
        .onChange(of: game.currentFloor) { _, _ in
            isFading = true
            withAnimation(.easeOut(duration: 0.45)) { spriteOpacity = 0 }
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                game.immediateSpawn()
                combatScene.updateZoneBackground(game.currentZone.id)
                combatScene.playHeroIdle()
                withAnimation(.easeIn(duration: 0.45)) { spriteOpacity = 1 }
                try? await Task.sleep(for: .milliseconds(450))
                isFading = false
            }
        }
        .onChange(of: game.isGameOver) { _, isOver in
            guard isOver else { return }
            if game.autoRestartEnabled {
                Task {
                    try? await Task.sleep(for: .seconds(1.2))
                    game.restart()
                    combatScene.playHeroIdle()
                    combatScene.playEnemyIdle()
                }
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(game.tickInterval))
                if !isFading {
                    game.tick()
                }
            }
        }
    }

    private var showSheet: Binding<Bool> {
        Binding(
            get: { selectedTab != .battle },
            set: { if !$0 { selectedTab = .battle } }
        )
    }

    @ViewBuilder
    private var sheetContent: some View {
        switch selectedTab {
        case .upgrades:
            UpgradesTabView(game: game)
        case .items:
            ItemsTabView(game: game)
        case .prestige:
            PrestigeTabView(game: game, onChangeCharacter: onChangeCharacter)
        case .quests:
            QuestsTabView(game: game)
        case .battle:
            EmptyView()
        }
    }
}

// MARK: - Offline Summary Overlay

struct OfflineSummaryView: View {
    let summary: OfflineSummary
    let adManager: AdManager
    let onDoubleGold: () -> Void
    let onDismiss: () -> Void

    @State private var didDoubleGold = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()

            VStack(spacing: 16) {
                Text("WHILE YOU WERE AWAY")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.75))

                Text(summary.durationString)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                VStack(spacing: 12) {
                    if summary.goldEarned > 0 {
                        summaryRow("Gold Earned", "+\(summary.goldEarned)g", .yellow)
                    }
                    if summary.floorsCleared > 0 {
                        summaryRow("Floors Cleared", "\(summary.floorsCleared)", .white)
                    }
                    summaryRow("Deepest Floor", DungeonGame.stageLabel(floor: summary.deepestFloor),
                               Color(red: 0.45, green: 0.72, blue: 1.00))
                    if summary.deaths > 0 {
                        summaryRow("Deaths", "\(summary.deaths)",
                                   Color(red: 1.0, green: 0.38, blue: 0.38))
                    }
                }

                if summary.stoppedByDeath {
                    Text("Unlock Undying Will to keep earning gold after death")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                }

                if summary.goldEarned > 0 {
                    if didDoubleGold {
                        Text("2× GOLD APPLIED!")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.yellow.opacity(0.85))
                    } else {
                        Button {
                            adManager.showOfflineAd {
                                onDoubleGold()
                                didDoubleGold = true
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.circle.fill")
                                Text(adManager.isOfflineAdReady ? "WATCH AD — 2× GOLD" : "LOADING AD...")
                            }
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(adManager.isOfflineAdReady
                                ? Color(red: 0.55, green: 0.42, blue: 0.08)
                                : Color(white: 0.18))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(adManager.isOfflineAdReady ? .white : Color.white.opacity(0.35))
                        }
                        .disabled(!adManager.isOfflineAdReady)
                    }
                }

                Button(action: onDismiss) {
                    Text("CONTINUE")
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.15, green: 0.38, blue: 0.72))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                }
                .padding(.top, 4)
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.09, green: 0.09, blue: 0.14))
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1))
            )
            .padding(.horizontal, 32)
            .onAppear {
                if StoreManager.shared.hasPurchasedRemoveAds, summary.goldEarned > 0, !didDoubleGold {
                    onDoubleGold()
                    didDoubleGold = true
                }
            }
        }
    }

    private func summaryRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.75))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Game Over Overlay

struct GameOverOverlay: View {
    let adManager: AdManager
    let onRevive: () -> Void
    let onRestart: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()

            VStack(spacing: 20) {
                Text("HERO FALLEN")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 1.0, green: 0.38, blue: 0.38))

                Text("Your run is over.\nGold, upgrades, and shards carry over.")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.75))
                    .multilineTextAlignment(.center)

                if StoreManager.shared.hasPurchasedRemoveAds {
                    Button(action: onRevive) {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.fill")
                            Text("REVIVE AT FULL HP")
                        }
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.62, green: 0.45, blue: 0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                    }
                } else {
                    Button {
                        adManager.showReviveAd(onReward: onRevive)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.circle.fill")
                            Text(adManager.isReviveAdReady ? "WATCH AD — REVIVE AT FULL HP" : "LOADING AD...")
                        }
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(adManager.isReviveAdReady
                            ? Color(red: 0.62, green: 0.45, blue: 0.12)
                            : Color(white: 0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(adManager.isReviveAdReady ? .white : Color.white.opacity(0.35))
                    }
                    .disabled(!adManager.isReviveAdReady)
                }

                Button(action: onRestart) {
                    Text("RESTART")
                        .font(.system(size: 17, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 36)
                        .padding(.vertical, 14)
                        .background(Color(red: 0.20, green: 0.55, blue: 0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.09, green: 0.09, blue: 0.14))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.10), lineWidth: 1))
            )
            .padding(.horizontal, 40)
        }
    }
}

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
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.75))
            Text(value)
                .font(.system(size: 15, weight: .medium, design: .monospaced))
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
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.75))
                HealthBar(pct: heroPct, color: heroColor)
                Text("\(game.heroHp) / \(game.heroMaxHp)")
                    .font(.system(size: 12, design: .monospaced).weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.75))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 5) {
                Text(game.displayMonsterName.isEmpty ? "NO ENEMY" : game.displayMonsterName.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(game.displayIsBoss
                        ? Color(red: 1.0, green: 0.55, blue: 0.10)
                        : Color.white.opacity(0.75))
                HealthBar(pct: monsterPct, color: Color(red: 0.85, green: 0.22, blue: 0.22))
                Text(game.displayMonsterMaxHp > 0
                     ? "\(game.displayMonsterHp) / \(game.displayMonsterMaxHp)"
                     : "—")
                    .font(.system(size: 12, design: .monospaced).weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.75))
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

// MARK: - Map

struct MapView: View {
    let game: DungeonGame

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(game.currentZone.icon)  \(game.currentZone.name)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                Spacer()
                if game.deepestFloorEver > 0 {
                    Text("BEST: \(DungeonGame.stageLabel(floor: game.deepestFloorEver))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.75))
                }
            }
            .padding(.horizontal, 20)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(Array(DungeonGame.zones.enumerated()), id: \.element.id) { idx, zone in
                            ZoneNodeView(
                                zone: zone,
                                isCurrent: game.currentZone.id == zone.id,
                                isPast: zone.maxFloor != nil && game.currentFloor > zone.maxFloor!,
                                everReached: game.deepestFloorEver >= zone.minFloor
                            )
                            .id(zone.id)
                            if idx < DungeonGame.zones.count - 1 {
                                Rectangle()
                                    .fill(zone.maxFloor != nil && game.currentFloor > zone.maxFloor!
                                          ? Color(white: 0.38) : Color(white: 0.18))
                                    .frame(width: 16, height: 2)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                }
                .onChange(of: game.currentZone.id) { _, id in
                    withAnimation(.easeInOut(duration: 0.5)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
        .padding(.vertical, 10)
    }
}

struct ZoneNodeView: View {
    let zone: Zone
    let isCurrent: Bool
    let isPast: Bool
    let everReached: Bool

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(circleFill)
                    .frame(width: 40, height: 40)
                    .shadow(color: isCurrent ? Color(red: 0.40, green: 0.68, blue: 1.00).opacity(0.6) : .clear,
                            radius: 8)
                Circle()
                    .stroke(borderColor, lineWidth: isCurrent ? 2.5 : 1.5)
                    .frame(width: 40, height: 40)
                Text(zone.icon)
                    .font(.system(size: 18, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(iconOpacity))
            }
            Text(zone.shortName)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(isCurrent ? Color.white : Color.white.opacity(textOpacity))
                .multilineTextAlignment(.center)
                .frame(width: 54)
            Text("Fl.\(zone.minFloor)\(zone.maxFloor.map { "-\($0)" } ?? "+")")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.30))
        }
    }

    private var circleFill: Color {
        if isCurrent   { return Color(red: 0.12, green: 0.28, blue: 0.62) }
        if isPast      { return Color(white: 0.22) }
        if everReached { return Color(white: 0.12) }
        return Color(white: 0.08)
    }

    private var borderColor: Color {
        if isCurrent   { return Color(red: 0.45, green: 0.72, blue: 1.00) }
        if isPast      { return Color(white: 0.50) }
        if everReached { return Color(white: 0.28) }
        return Color(white: 0.15)
    }

    private var iconOpacity: Double {
        if isCurrent || isPast { return 1.0 }
        if everReached          { return 0.55 }
        return 0.22
    }

    private var textOpacity: Double {
        if isPast      { return 0.80 }
        if everReached { return 0.50 }
        return 0.22
    }
}

// MARK: - Battle Tab

struct BattleTabView: View {
    let game: DungeonGame
    let combatScene: CombatScene
    let spriteOpacity: Double

    var body: some View {
        VStack(spacing: 0) {
            SpriteView(scene: combatScene, options: [.allowsTransparency])
                .frame(height: 260)
                .frame(maxWidth: .infinity)
                .opacity(spriteOpacity)
            CombatStatusView(game: game)
            MapView(game: game)
            ActiveEffectsBarView(game: game)
            ConsumablesBarView(game: game)
            if let event = game.pendingFloorEvent {
                FloorEventCardView(game: game, event: event)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            Spacer()
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: game.pendingFloorEvent?.id)
        .background(Color(red: 0.07, green: 0.07, blue: 0.11))
    }
}

// MARK: - Active Effects Bar

struct ActiveEffectsBarView: View {
    let game: DungeonGame
    @State private var selectedEffect: ActiveEffect?

    var body: some View {
        if !game.activeEffects.isEmpty {
            let rows = stride(from: 0, to: game.activeEffects.count, by: 3).map {
                Array(game.activeEffects[$0..<min($0 + 3, game.activeEffects.count)])
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 8) {
                        ForEach(row) { effect in
                            effectPill(effect)
                                .onTapGesture { selectedEffect = effect }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .sheet(item: $selectedEffect) { effect in
                EffectDetailView(effect: effect)
                    .presentationDetents([.height(260)])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Color(red: 0.07, green: 0.07, blue: 0.11))
            }
        }
    }

    private func effectPill(_ effect: ActiveEffect) -> some View {
        HStack(spacing: 5) {
            Text(effect.icon)
                .font(.system(size: 13))
            Text(effect.name)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(effect.isBlessing ? Color(red: 0.4, green: 0.95, blue: 0.55)
                                                   : Color(red: 1.0, green: 0.5, blue: 0.5))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(effect.isBlessing ? Color(red: 0.05, green: 0.18, blue: 0.08)
                                        : Color(red: 0.20, green: 0.05, blue: 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(effect.isBlessing ? Color(red: 0.25, green: 0.65, blue: 0.3)
                                                        : Color(red: 0.65, green: 0.25, blue: 0.25),
                                      lineWidth: 1)
                )
        )
    }
}

// MARK: - Consumables Bar

struct ConsumablesBarView: View {
    let game: DungeonGame

    var body: some View {
        let vials = game.usableItems.filter { $0.kind == .fullHeal }
        if !vials.isEmpty {
            HStack(spacing: 8) {
                ForEach(vials) { vial in
                    Button { game.useItem(vial) } label: {
                        HStack(spacing: 5) {
                            Text(vial.icon)
                                .font(.system(size: 13))
                            Text("Holy Vial")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white)
                            Text("USE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(red: 0.4, green: 0.95, blue: 0.55))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(red: 0.05, green: 0.18, blue: 0.08))
                                .overlay(RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color(red: 0.25, green: 0.65, blue: 0.3), lineWidth: 1))
                        )
                    }
                    .buttonStyle(.plain)
                    .opacity(game.isGameOver ? 0.35 : 1.0)
                    .disabled(game.isGameOver)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }
}

struct EffectDetailView: View {
    let effect: ActiveEffect

    private var accentColor: Color {
        effect.isBlessing ? Color(red: 0.3, green: 0.85, blue: 0.45) : Color(red: 0.95, green: 0.35, blue: 0.35)
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text(effect.icon)
                    .font(.system(size: 44))
                Text(effect.name)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(accentColor)
                Text(effect.isBlessing ? "BLESSING" : "CURSE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(accentColor.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(accentColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            VStack(spacing: 10) {
                if effect.atkMod != 0 {
                    effectRow(label: "Attack", value: effect.atkMod)
                }
                if effect.defMod != 0 {
                    effectRow(label: "Defense", value: effect.defMod)
                }
                if effect.maxHpMod != 0 {
                    effectRow(label: "Max HP", value: effect.maxHpMod)
                }
                if effect.regenMod != 0 {
                    effectRow(label: "HP Regen", value: effect.regenMod)
                }
            }
            .padding(.horizontal, 32)
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity)
    }

    private func effectRow(label: String, value: Int) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(white: 0.6))
            Spacer()
            Text(value > 0 ? "+\(value)" : "\(value)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(value > 0 ? Color(red: 0.3, green: 0.85, blue: 0.45)
                                           : Color(red: 0.95, green: 0.35, blue: 0.35))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(white: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Floor Event Card

struct FloorEventCardView: View {
    let game: DungeonGame
    let event: FloorEvent

    var body: some View {
        let t = event.template
        let canAfford = t.primaryGoldCost == 0 || game.gold >= t.primaryGoldCost

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(t.icon)
                    .font(.system(size: 32))
                VStack(alignment: .leading, spacing: 4) {
                    Text(categoryLabel(t.category))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(categoryColor(t.category))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(categoryColor(t.category).opacity(0.15))
                        )
                    Text(t.title)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }
                Spacer()
            }

            Text(t.flavorText)
                .font(.system(size: 12, design: .monospaced).italic())
                .foregroundStyle(Color.white.opacity(0.50))
                .fixedSize(horizontal: false, vertical: true)

            Divider()
                .background(Color.white.opacity(0.10))

            HStack(spacing: 10) {
                eventButton(
                    label: t.primaryLabel,
                    summary: t.primaryEffectSummary,
                    active: canAfford,
                    accent: canAfford ? categoryColor(t.category) : Color.white.opacity(0.3)
                ) { game.resolveFloorEvent(primary: true) }

                eventButton(
                    label: t.secondaryLabel,
                    summary: t.secondaryEffectSummary,
                    active: true,
                    accent: Color.white.opacity(0.35)
                ) { game.resolveFloorEvent(primary: false) }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.10, green: 0.10, blue: 0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(categoryColor(t.category).opacity(0.6), lineWidth: 1.5)
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func eventButton(label: String, summary: String, active: Bool, accent: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(active ? accent : Color.white.opacity(0.25))
                Text(summary)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(active ? accent.opacity(0.12) : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(active ? accent.opacity(0.4) : Color.white.opacity(0.10),
                                          lineWidth: 1)
                    )
            )
        }
        .disabled(!active)
        .buttonStyle(.plain)
    }

    private func categoryLabel(_ cat: FloorEventTemplate.Category) -> String {
        switch cat {
        case .blessing: return "BLESSING"
        case .shrine:   return "SHRINE"
        case .curse:    return "CURSE"
        case .mystery:  return "MYSTERY"
        }
    }

    private func categoryColor(_ cat: FloorEventTemplate.Category) -> Color {
        switch cat {
        case .blessing: return Color(red: 0.30, green: 0.85, blue: 0.45)
        case .shrine:   return Color(red: 0.95, green: 0.78, blue: 0.25)
        case .curse:    return Color(red: 0.95, green: 0.35, blue: 0.35)
        case .mystery:  return Color(red: 0.65, green: 0.35, blue: 0.95)
        }
    }
}

// MARK: - Tab Navigation

private enum GameTab { case battle, upgrades, prestige, items, quests }

private struct CustomGameTabBar: View {
    @Binding var selectedTab: GameTab
    let hasClaimableQuest: Bool

    private struct TabDef {
        let tab: GameTab
        let label: String
        let icon: String
    }

    private let tabs: [TabDef] = [
        .init(tab: .upgrades, label: "UPGRADES", icon: "arrow.up.circle.fill"),
        .init(tab: .items,    label: "ITEMS",    icon: "bag.fill"),
        .init(tab: .battle,   label: "BATTLE",   icon: "shield.fill"),
        .init(tab: .prestige, label: "PRESTIGE", icon: "sparkles"),
        .init(tab: .quests,   label: "QUESTS",   icon: "scroll.fill"),
    ]

    private let barColor        = Color(red: 0.07, green: 0.07, blue: 0.11)
    private let selectedColor   = Color(red: 0.90, green: 0.70, blue: 0.28)
    private let unselectedColor = Color.white.opacity(0.38)

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.label) { def in
                tabButton(def)
            }
        }
        .frame(height: 56)
        .background(barColor.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(height: 1)
        }
    }

    private func tabButton(_ def: TabDef) -> some View {
        let isSelected = selectedTab == def.tab
        let isBattle   = def.tab == .battle
        let showBadge  = def.tab == .quests && hasClaimableQuest

        return Button {
            Haptics.impact(.light)
            selectedTab = def.tab
        } label: {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: def.icon)
                        .font(.system(size: isBattle ? 22 : 18, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? selectedColor : unselectedColor)
                        .frame(width: 28, height: 24)

                    if showBadge {
                        Circle()
                            .fill(Color(red: 1.0, green: 0.35, blue: 0.35))
                            .frame(width: 7, height: 7)
                            .offset(x: 5, y: -2)
                    }
                }

                Text(def.label)
                    .font(.system(size: 8, weight: isSelected ? .bold : .regular, design: .monospaced))
                    .foregroundStyle(isSelected ? selectedColor : unselectedColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .overlay(alignment: .top) {
                if isSelected {
                    Capsule()
                        .fill(selectedColor)
                        .frame(width: 20, height: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Upgrades Tab

struct UpgradesTabView: View {
    let game: DungeonGame

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(game.upgrades) { upgrade in
                    let isLocked = upgrade.unlockFloor > 0 && game.deepestFloorEver < upgrade.unlockFloor
                    let unlockZone = DungeonGame.zones.first(where: { $0.minFloor == upgrade.unlockFloor })?.name
                    let cost = game.effectiveCost(for: upgrade)
                    UpgradeRowView(
                        upgrade: upgrade,
                        displayCost: cost,
                        canAfford: game.gold >= cost,
                        isLocked: isLocked,
                        unlockZoneName: unlockZone
                    ) {
                        game.buyUpgrade(id: upgrade.id)
                        SoundManager.shared.play("weapon_upgrade")
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

// MARK: - Prestige Tab

struct PrestigeTabView: View {
    let game: DungeonGame
    let onChangeCharacter: () -> Void
    @State private var showStore = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                PrestigeRowView(game: game)

                Text("PERMANENT UPGRADES")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.top, 8)

                ForEach(game.prestigeUpgrades) { upgrade in
                    PrestigeUpgradeRowView(
                        upgrade: upgrade,
                        canAfford: game.soulShards >= upgrade.shardCost
                    ) {
                        game.buyPrestigeUpgrade(id: upgrade.id)
                        SoundManager.shared.play("8_bit_chime_positive")
                    }
                }

                Button(action: onChangeCharacter) {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 14))
                        Text("CHANGE HERO")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    }
                    .foregroundStyle(Color.white.opacity(0.70))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(white: 0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 8)

                Button { showStore = true } label: {
                    HStack {
                        Image(systemName: "cart.fill")
                            .font(.system(size: 14))
                        Text("SUPPORT THE GAME")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    }
                    .foregroundStyle(Color(red: 1.00, green: 0.75, blue: 0.25).opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(white: 0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(red: 1.00, green: 0.75, blue: 0.25).opacity(0.22), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 32)
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.11))
        .sheet(isPresented: $showStore) { StoreSheetView() }
    }
}

// MARK: - Upgrade Row

struct UpgradeRowView: View {
    let upgrade: Upgrade
    let displayCost: Int
    let canAfford: Bool
    let isLocked: Bool
    let unlockZoneName: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(upgrade.name)
                            .font(.system(size: 16, design: .monospaced))
                            .foregroundStyle(isLocked ? Color.white.opacity(0.30) : .white)
                        if !isLocked && upgrade.level > 0 {
                            Text("Lv \(upgrade.level)")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.90))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.18))
                                .clipShape(Capsule())
                        }
                    }
                    Text(isLocked ? "Reach \(unlockZoneName ?? "next zone") to unlock" : upgrade.currentEffect)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(isLocked ? Color.white.opacity(0.25) : .white)
                }
                Spacer()
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.white.opacity(0.20))
                } else {
                    Text("\(displayCost)g")
                        .font(.system(size: 18, design: .monospaced).weight(.semibold))
                        .foregroundStyle(canAfford ? .yellow : Color.white.opacity(0.35))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isLocked ? Color(white: 0.07) : Color(white: 0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isLocked ? Color.white.opacity(0.04)
                                         : canAfford ? Color.green.opacity(0.38) : Color.white.opacity(0.07),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
    }
}

// MARK: - Prestige Upgrade Row

struct PrestigeUpgradeRowView: View {
    let upgrade: PrestigeUpgrade
    let canAfford: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(upgrade.name)
                            .font(.system(size: 16, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(upgrade.isMaxed ? 0.4 : 1.0))
                        Text("Lv \(upgrade.level)/\(upgrade.maxLevel)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.75))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    Text(upgrade.level == 0 ? upgrade.detail : upgrade.currentEffect)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.75))
                }
                Spacer()
                if upgrade.isMaxed {
                    Text("MAX")
                        .font(.system(size: 13, design: .monospaced).weight(.semibold))
                        .foregroundStyle(Color(red: 0.70, green: 0.50, blue: 1.00))
                } else {
                    Text("\(upgrade.shardCost) ◈")
                        .font(.system(size: 18, design: .monospaced).weight(.semibold))
                        .foregroundStyle(canAfford ? Color(red: 0.70, green: 0.50, blue: 1.00) : Color.white.opacity(0.35))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(white: 0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                upgrade.isMaxed
                                    ? Color(red: 0.50, green: 0.30, blue: 0.80).opacity(0.45)
                                    : canAfford
                                        ? Color(red: 0.50, green: 0.30, blue: 0.80).opacity(0.38)
                                        : Color.white.opacity(0.07),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(upgrade.isMaxed)
    }
}

// MARK: - Prestige Row

struct PrestigeRowView: View {
    let game: DungeonGame

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("Prestige")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundStyle(game.canPrestige() ? Color(red: 0.72, green: 0.52, blue: 1.00) : .white)
                Text(subtitle)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.75))
            }
            Spacer()
            if game.canPrestige() {
                Button {
                    game.prestige()
                } label: {
                    Text("+\(game.prestigeShardValue()) shards")
                        .font(.system(size: 14, design: .monospaced).weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(Color(red: 0.55, green: 0.35, blue: 0.85))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(white: 0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            game.canPrestige()
                                ? Color(red: 0.50, green: 0.30, blue: 0.80).opacity(0.45)
                                : Color.white.opacity(0.07),
                            lineWidth: 1
                        )
                )
        )
    }

    private var subtitle: String {
        if game.canPrestige() {
            return "Best floor \(game.deepestFloor) — reset for \(game.prestigeShardValue()) shards"
        }
        let threshold = game.prestigeThreshold
        return game.deepestFloor > 0
            ? "Best: floor \(game.deepestFloor) — need floor \(threshold)"
            : "Reach floor \(threshold) to unlock"
    }
}

// MARK: - Rarity colors

extension ItemRarity {
    var uiColor: Color {
        switch self {
        case .common:    return .white
        case .uncommon:  return Color(red: 0.22, green: 0.82, blue: 0.35)
        case .rare:      return Color(red: 0.25, green: 0.55, blue: 1.00)
        case .epic:      return Color(red: 0.72, green: 0.30, blue: 1.00)
        case .legendary: return Color(red: 1.00, green: 0.65, blue: 0.10)
        }
    }
}

// MARK: - Item Icon

struct ItemIconView: View {
    let item: Equipment
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(item.rarity.uiColor.opacity(0.18))
            RoundedRectangle(cornerRadius: 6)
                .stroke(item.rarity.uiColor, lineWidth: 1.5)
            Image(item.iconName)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .padding(5)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Items Tab

struct ItemsTabView: View {
    let game: DungeonGame

    var body: some View {
        VStack(spacing: 0) {
            // Fixed equipped section
            VStack(spacing: 14) {
                HStack {
                    Text("EQUIPPED GEAR")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.50))
                    Spacer()
                    if !game.inventory.isEmpty {
                        Button(action: { game.optimizeEquipment() }) {
                            HStack(spacing: 5) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 11))
                                Text("OPTIMIZE")
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.18, green: 0.42, blue: 0.22))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(alignment: .top, spacing: 10) {
                    ForEach(EquipmentSlot.allCases, id: \.self) { slot in
                        EquippedGearCard(
                            slot: slot,
                            item: game.equippedItems[slot.rawValue],
                            onUnequip: { game.unequip(slot: slot) },
                            onSell: { game.sellEquipped(slot: slot) }
                        )
                    }
                }

                if let bonus = game.appliedSetBonus {
                    SetBonusCardView(rarity: bonus, summary: game.setBonusSummary(bonus))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            Divider()
                .background(Color.white.opacity(0.08))

            // Scrollable inventory
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    let charms = game.usableItems.filter { $0.kind == .revive }
                    if !charms.isEmpty {
                        Text("CONSUMABLES  \(game.usableItems.count)/\(DungeonGame.usableItemLimit)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.50))
                            .padding(.horizontal, 4)

                        ForEach(charms) { item in
                            UsableItemView(item: item, onUse: { game.useItem(item) })
                        }

                        if !game.inventory.isEmpty {
                            Divider()
                                .background(Color.white.opacity(0.10))
                                .padding(.vertical, 4)
                        }
                    }

                    if !game.inventory.isEmpty {
                        Text("INVENTORY  \(game.inventory.count)/\(EquipmentDrop.inventoryLimit)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.50))
                            .padding(.horizontal, 4)

                        ForEach(game.inventory.reversed()) { item in
                            InventoryItemView(
                                item: item,
                                onEquip: { game.equip(item: item) },
                                onSell:  { game.sellItem(item) }
                            )
                        }
                    } else if game.equippedItems.isEmpty && charms.isEmpty {
                        Text("Items drop from enemies as you fight.\nCheck back after a few battles.")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.40))
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 24)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.11))
    }
}

// MARK: - Equipped Gear Card

struct EquippedGearCard: View {
    let slot: EquipmentSlot
    let item: Equipment?
    let onUnequip: () -> Void
    let onSell: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(slot.label.uppercased())
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.40))
                .padding(.bottom, 8)

            if let item {
                ItemIconView(item: item, size: 38)
                    .padding(.bottom, 8)

                Text(item.name)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)

                Text(item.rarity.label)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(item.rarity.uiColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(item.rarity.uiColor.opacity(0.15))
                    .clipShape(Capsule())
                    .padding(.bottom, 8)

                Text(item.statSummary)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.60))
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 10)

                HStack(spacing: 6) {
                    Button(action: onSell) {
                        Text("\(item.sellValue)g")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.yellow)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(Color(red: 0.30, green: 0.22, blue: 0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)

                    Button(action: onUnequip) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.45))
                            .frame(width: 26)
                            .padding(.vertical, 5)
                            .background(Color(white: 0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: slotSymbol)
                        .font(.system(size: 26))
                        .foregroundStyle(Color.white.opacity(0.12))
                    Text("EMPTY")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.22))
                }
                .frame(maxWidth: .infinity)
                Spacer()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 170)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            item.map { $0.rarity.uiColor.opacity(0.28) } ?? Color.white.opacity(0.07),
                            lineWidth: 1
                        )
                )
        )
    }

    private var slotSymbol: String {
        switch slot {
        case .weapon: return "shield.lefthalf.filled"
        case .armor:  return "square.stack.3d.up"
        case .ring:   return "circle.circle"
        }
    }
}

// MARK: - Usable Item Row

struct UsableItemView: View {
    let item: UsableItem
    let onUse: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(item.icon)
                .font(.system(size: 26))
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                Text(item.kind == .fullHeal ? "Restore HP to full" : "Auto-triggers on death")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.55))
            }

            Spacer()

            if item.kind == .fullHeal {
                Button(action: onUse) {
                    Text("USE")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color(red: 0.18, green: 0.42, blue: 0.22))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            } else {
                Text("AUTO")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.60, green: 0.45, blue: 0.95))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(red: 0.60, green: 0.45, blue: 0.95).opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(white: 0.09))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(red: 0.55, green: 0.55, blue: 1.0).opacity(0.30), lineWidth: 1))
        )
    }
}

// MARK: - Inventory Item Row

struct InventoryItemView: View {
    let item: Equipment
    let onEquip: () -> Void
    let onSell: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ItemIconView(item: item, size: 40)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                    Text(item.rarity.label)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(item.rarity.uiColor)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(item.rarity.uiColor.opacity(0.15))
                        .clipShape(Capsule())
                }
                Text(item.statSummary)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.75))
                Text("\(DungeonGame.stageLabel(floor: item.floorFound))  •  \(item.slot.label)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.30))
            }

            Spacer()

            VStack(spacing: 5) {
                Button(action: onEquip) {
                    Text("EQUIP")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(red: 0.15, green: 0.38, blue: 0.72))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button(action: onSell) {
                    Text("SELL \(item.sellValue)g")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(red: 0.35, green: 0.25, blue: 0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .foregroundStyle(.yellow)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(white: 0.09))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(item.rarity.uiColor.opacity(0.18), lineWidth: 1))
        )
    }
}

// MARK: - Boss Victory Overlay

struct BossVictoryOverlay: View {
    let victory: BossVictory
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()

            VStack(spacing: 0) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color(red: 1.0, green: 0.80, blue: 0.15))
                    .padding(.bottom, 14)

                Text("ZONE CLEARED!")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.20))

                Text("Stage \(victory.stageLabel)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.50))
                    .padding(.top, 4)
                    .padding(.bottom, 18)

                Divider()
                    .background(Color.white.opacity(0.12))
                    .padding(.bottom, 16)

                Text(victory.zoneIcon + "  " + victory.zoneName.uppercased())
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)

                Text("\(victory.bossName) Defeated")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .padding(.top, 4)
                    .padding(.bottom, 20)

                Divider()
                    .background(Color.white.opacity(0.12))
                    .padding(.bottom, 18)

                HStack(spacing: 36) {
                    VStack(spacing: 4) {
                        Text("GOLD")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.50))
                        Text("+\(victory.goldEarned)g")
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundStyle(.yellow)
                    }

                    VStack(spacing: 4) {
                        Text("REWARD")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.50))
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 13))
                            Text("Item Drop!")
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        }
                        .foregroundStyle(Color(red: 0.72, green: 0.45, blue: 1.00))
                    }
                }
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(red: 0.09, green: 0.09, blue: 0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color(red: 1.0, green: 0.82, blue: 0.20).opacity(0.35), lineWidth: 1.5)
                    )
                    .shadow(color: Color(red: 1.0, green: 0.75, blue: 0.10).opacity(0.15), radius: 24)
            )
            .padding(.horizontal, 28)
        }
        .onTapGesture { onDismiss() }
        .task {
            try? await Task.sleep(for: .seconds(4))
            onDismiss()
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(.spring(response: 0.4), value: victory.stageLabel)
    }
}

// MARK: - Item Drop Banner

struct ItemDropBanner: View {
    let item: Equipment
    let onDismiss: () -> Void

    var body: some View {
        Button(action: onDismiss) {
            HStack(spacing: 12) {
                ItemIconView(item: item, size: 46)

                VStack(alignment: .leading, spacing: 3) {
                    Text("ITEM FOUND!")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(item.rarity.uiColor)
                    Text(item.name)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Text(item.statSummary)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.75))
                }

                Spacer()

                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.40))
                    .padding(.trailing, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(red: 0.09, green: 0.09, blue: 0.14))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(item.rarity.uiColor.opacity(0.45), lineWidth: 1.5))
                    .shadow(color: item.rarity.uiColor.opacity(0.20), radius: 12)
            )
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
        .task {
            try? await Task.sleep(for: .seconds(4))
            onDismiss()
        }
    }
}

// MARK: - Zone Unlock Overlay

struct ZoneUnlockOverlay: View {
    let zone: Zone
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()

            VStack(spacing: 0) {
                Text("NEW ZONE UNLOCKED")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.35, green: 0.85, blue: 0.45))
                    .padding(.bottom, 14)

                Text(zone.icon)
                    .font(.system(size: 52))
                    .padding(.bottom, 10)

                Text(zone.name.uppercased())
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Floor \(zone.minFloor)\(zone.maxFloor.map { "–\($0)" } ?? "+")")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.50))
                    .padding(.top, 6)
            }
            .padding(36)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(red: 0.07, green: 0.13, blue: 0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color(red: 0.30, green: 0.72, blue: 0.42).opacity(0.45), lineWidth: 1.5)
                    )
                    .shadow(color: Color(red: 0.25, green: 0.80, blue: 0.40).opacity(0.18), radius: 24)
            )
            .padding(.horizontal, 36)
        }
        .onTapGesture { onDismiss() }
        .task {
            try? await Task.sleep(for: .seconds(3))
            onDismiss()
        }
        .transition(.opacity.combined(with: .scale(scale: 0.92)))
        .animation(.spring(response: 0.45), value: zone.id)
    }
}

// MARK: - Set Bonus Card

struct SetBonusCardView: View {
    let rarity: ItemRarity
    let summary: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 18))
                .foregroundStyle(rarity.uiColor)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("\(rarity.label) Set Bonus")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("ACTIVE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(rarity.uiColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(rarity.uiColor.opacity(0.18))
                        .clipShape(Capsule())
                }
                Text(summary)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.75))
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(rarity.uiColor.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(rarity.uiColor.opacity(0.35), lineWidth: 1)
                )
        )
    }
}

// MARK: - Quests Tab

struct QuestsTabView: View {
    let game: DungeonGame

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack {
                    Text("DAILY QUESTS")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.50))
                    Spacer()
                    Text("Resets at midnight")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.28))
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
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Color.yellow.opacity(0.50))
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
                    Text("Complete all \(12) daily quests")
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
