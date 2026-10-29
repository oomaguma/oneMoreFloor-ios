// GameView.swift
// GameView owns the game loop (.task -> game.tick()), wires the SpriteKit
// combat callbacks, and hosts the tabs, sheets, and overlays.

import SwiftUI
import UIKit

// MARK: - Game View

struct GameView: View {
    let character: CharacterClass
    let onChangeCharacter: (DungeonGame) -> Void

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
    @AppStorage("com.oneMoreFloor.notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("com.oneMoreFloor.autoBattleEnabled")    private var autoBattle           = false
    @AppStorage("com.oneMoreFloor.seenIntro")            private var seenIntro            = false
    @State private var showIntro = false
    // Juice triggers: each bump plays one screen shake / red hurt flash.
    @State private var shakeTrigger = 0
    @State private var hurtTrigger  = 0

    init(character: CharacterClass, onChangeCharacter: @escaping (DungeonGame) -> Void) {
        self.character = character
        self.onChangeCharacter = onChangeCharacter
        let g = DungeonGame(character: character)
        let initialEnemy = g.currentEnemyType ?? EnemyType.slime
        _game = State(initialValue: g)
        _combatScene = State(initialValue: CombatScene(hero: character, initialEnemy: initialEnemy, initialZoneID: g.currentZone.id))
    }

    var body: some View {
        ZStack {
            Theme.Palette.abyss
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // The battle screen now owns its own floating header (floor,
                // currencies, controls) so the dungeon art can run full-bleed
                // underneath it. GameView just hands it the controls it needs.
                BattleTabView(game: game,
                              combatScene: combatScene,
                              spriteOpacity: spriteOpacity,
                              autoBattle: $autoBattle,
                              onSettings: { showSettings = true },
                              onStore: { showStore = true },
                              shakeTrigger: shakeTrigger,
                              hurtTrigger: hurtTrigger)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                CustomGameTabBar(selectedTab: $selectedTab, hasClaimableQuest: game.hasClaimableQuest)
            }
            .sheet(isPresented: $showStore) {
                StoreSheetView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationSizing(.page)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationSizing(.page)
            }

            // Item drop banner — non-blocking top banner; hidden when a full-screen overlay is up
            if let drop = game.pendingDrop, !isAnyFullScreenOverlayActive {
                VStack {
                    ItemDropBanner(item: drop, onDismiss: { game.dismissDrop() })
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    Spacer()
                }
                .animation(.spring(response: 0.4), value: game.pendingDrop?.id)
            }

            // Blessing banner — auto-applied free buff; brief and non-blocking,
            // held back behind a drop banner or any full-screen overlay.
            if let blessing = game.pendingBlessing, game.pendingDrop == nil, !isAnyFullScreenOverlayActive {
                VStack {
                    BlessingBanner(template: blessing, onDismiss: { game.dismissBlessing() })
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                    Spacer()
                }
                .animation(.spring(response: 0.4), value: game.pendingBlessing)
            }

            // Full-screen overlays in strict priority order — only one is ever shown at a time
            if let victory = game.pendingBossVictory {
                BossVictoryOverlay(victory: victory) { game.dismissBossVictory() }
            } else if let zone = game.pendingZoneUnlock {
                ZoneUnlockOverlay(zone: zone) { game.dismissZoneUnlock() }
            } else if game.isGameOver {
                GameOverOverlay(
                    game: game,
                    adManager: adManager,
                    onRevive: {
                        game.revive()
                        game.save()
                        combatScene.playHeroIdle()
                        combatScene.playEnemyIdle()
                    },
                    onRestart: {
                        game.restart()
                        combatScene.playHeroIdle()
                        combatScene.playEnemyIdle()
                    }
                )
            } else if let summary = offlineSummary {
                OfflineSummaryView(
                    summary: summary,
                    adManager: adManager,
                    onDoubleGold: { game.gold += summary.goldEarned },
                    onDismiss: { offlineSummary = nil }
                )
            } else if game.pendingRestSite {
                ZStack {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                    VStack {
                        Spacer()
                        RestSiteCardView(game: game, adManager: adManager)
                        Spacer()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: game.pendingRestSite)
            } else if let event = game.pendingFloorEvent {
                ZStack {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                    VStack {
                        Spacer()
                        FloorEventCardView(game: game, event: event)
                        Spacer()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: event.id)
            } else if game.isRaidScreenUp {
                // Full-screen raid takeover — shown above everything else while the
                // side-scrolling arena combat plays out. Returns to dungeon when done.
                RaidView(game: game)
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: showSheet) {
            sheetContent
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationSizing(.page)
        }
        // One-time explanation when a raid was lost by closing the app mid-raid
        // (see DungeonGame.handleForeground). Dismissing clears the notice.
        .alert("Raid abandoned",
               isPresented: Binding(get: { game.abandonedRaid != nil },
                                    set: { if !$0 { game.abandonedRaid = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(abandonedRaidMessage)
        }
        .fullScreenCover(isPresented: $showIntro) {
            IntroCardView(onBegin: { seenIntro = true; showIntro = false })
        }
        .preferredColorScheme(.dark)
        .onAppear {
            game.autoBattle = autoBattle
            if !seenIntro { showIntro = true }   // first-run onboarding
            if let summary = game.handleForeground() {
                offlineSummary = summary
            }
            #if DEBUG
            // QA shortcuts (-debugRaid / -debugBlessings) — see Debug/DebugLaunch.swift.
            // Applied after the offline sim so it can't immediately undo them.
            game.applyDebugLaunchArguments()
            if UserDefaults.standard.integer(forKey: "debugRaid") > 0 { offlineSummary = nil }
            #endif
            combatScene.updateZoneBackground(game.currentZone.id)
            if let enemy = game.currentEnemyType {
                combatScene.updateEnemy(enemy)
                combatScene.playEnemyIdle()
            }
            combatScene.playHeroIdle()

            game.onHeroAttack = {
                combatScene.playHeroAttack()
            }
            game.onHeroHurt = {
                combatScene.playHeroHurt()
                hurtTrigger += 1
            }
            game.onHeroDeath = {
                combatScene.playHeroDeath()
                shakeTrigger += 1
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
                shakeTrigger += 1
            }
            game.onHeroHeal = { amt in
                combatScene.showHeroHeal(amt)
                combatScene.playHeroHeal()
            }
            game.onHeroDodge   = { combatScene.showDodge() }
            game.onEnemyWindup = {
                combatScene.showTelegraph()
                Haptics.notify(.warning)
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
            // Skip the "hero has fallen" notification when the player opted out, or for
            // Remove Ads buyers since they get a free revive and the character carries on.
            if notificationsEnabled,
               !StoreManager.shared.hasPurchasedRemoveAds,
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
        .onChange(of: autoBattle) { _, newValue in
            game.autoBattle = newValue   // keep the model's live flag in sync with the toggle
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
        // Foreground death always shows the revive/restart overlay now — even with
        // Undying Will — so the Second Wind ad and the at-risk gold aren't skipped.
        // Auto-restart applies only to offline farming (see simulateOffline).
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(game.tickInterval))
                // Combat ticks only on the battle screen with nothing blocking:
                // paused during transitions, the rest decision, and whenever a
                // menu/sheet is open so the player has time to manage. In manual
                // mode the tick only handles regen/spawn; taps drive the fight.
                let menuOpen = selectedTab != .battle || showStore || showSettings || showIntro
                if !isFading && !game.pendingRestSite && !game.isRaidScreenUp && !menuOpen {
                    game.tick()
                }
            }
        }
    }

    /// What the abandoned-raid alert says it cost, skipping anything that was zero.
    private var abandonedRaidMessage: String {
        guard let lost = game.abandonedRaid else { return "" }
        var costs: [String] = []
        if lost.blessingsLost > 0 { costs.append("\(lost.blessingsLost) blessing\(lost.blessingsLost == 1 ? "" : "s")") }
        if lost.goldLost > 0      { costs.append("\(lost.goldLost) gold") }
        let cost = costs.isEmpty ? "" : " You lost " + costs.joined(separator: " and ") + "."
        return "Leaving mid-raid counts as a loss." + cost
    }

    // True whenever any full-screen overlay is displayed, so the item drop banner stays hidden
    private var isAnyFullScreenOverlayActive: Bool {
        game.pendingBossVictory != nil ||
        game.pendingZoneUnlock != nil ||
        game.isGameOver ||
        offlineSummary != nil ||
        game.pendingRestSite ||
        game.pendingFloorEvent != nil ||
        game.isRaidScreenUp
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
            PrestigeTabView(game: game, combatScene: combatScene, onChangeCharacter: { onChangeCharacter(game) })
        case .quests:
            QuestsTabView(game: game)
        case .battle:
            EmptyView()
        }
    }
}
