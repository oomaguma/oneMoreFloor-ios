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
    // Players who saw the old text-wall intro have already learned the basics.
    @AppStorage("com.oneMoreFloor.seenIntro")            private var seenIntro            = false
    // First-session tutorial progress (see Onboarding/Tutorial.swift).
    @AppStorage(TutorialStep.storageKey)                 private var tutorialStepRaw      = 0
    @AppStorage(TutorialStep.dropGivenKey)               private var tutorialDropGiven    = false
    /// Set when a returning player's hero died while away and iOS has never
    /// asked about notifications — the offline summary then offers a soft ask.
    @State private var offerNotificationAsk = false
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
                              hurtTrigger: hurtTrigger,
                              tutorialStepRaw: $tutorialStepRaw)
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
                    ItemDropBanner(item: drop,
                                   wasEquipped: game.equippedItems[drop.slot.rawValue]?.id == drop.id,
                                   onDismiss: { game.dismissDrop() })
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
                    offerNotifications: offerNotificationAsk,
                    onEnableNotifications: { NotificationManager.shared.requestPermission() },
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
        .preferredColorScheme(.dark)
        .onAppear {
            game.autoBattle = autoBattle
            // Anyone who saw the old intro skips the new tutorial.
            if seenIntro && tutorialStepRaw == TutorialStep.strike.rawValue {
                tutorialStepRaw = TutorialStep.done.rawValue
            }
            if let summary = game.handleForeground() {
                offlineSummary = summary
            }
            #if DEBUG
            // QA shortcuts (-debugRaid / -debugBlessings) — see Debug/DebugLaunch.swift.
            // Applied after the offline sim so it can't immediately undo them.
            game.applyDebugLaunchArguments()
            if UserDefaults.standard.integer(forKey: "debugRaid") > 0 { offlineSummary = nil }
            if let fake = DungeonGame.debugOfflineDeathSummary { offlineSummary = fake }
            #endif
            // Put an enemy in front of the player right away. A fresh run used to
            // open on ~4s of "…" before the first fight — dead air in exactly the
            // minute that decides whether a new player sticks around. (No-op if a
            // fight is already in progress.)
            game.immediateSpawn()
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
            // The buzz scales with rarity, so a Legendary *feels* different
            // in the hand before you've even read the banner.
            guard newID != nil, let rarity = game.pendingDrop?.rarity else { return }
            SoundManager.shared.play("item_equip")
            switch rarity {
            case .common:          Haptics.impact(.light)
            case .uncommon:        Haptics.impact(.medium)
            case .rare:            Haptics.impact(.heavy)
            case .epic, .legendary: Haptics.notify(.success)
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
        .onChange(of: offlineSummary?.deaths ?? 0) { _, deaths in
            // Hero died while away → check whether iOS can still be asked.
            guard deaths > 0 else { offerNotificationAsk = false; return }
            Task {
                offerNotificationAsk = await NotificationManager.shared.canAskForPermission()
                if offerNotificationAsk { Analytics.notificationAskShown() }
            }
        }
        .onChange(of: tutorialStepRaw) { _, raw in
            // Tutorial funnel: log each hint step as it's reached. "done" is
            // skipped — finishTutorial() already sends tutorial_completed, and
            // returning players jump straight to done without seeing any step.
            guard let step = TutorialStep(rawValue: raw), step != .done else { return }
            Analytics.tutorialStepReached(String(describing: step))
        }
        .onChange(of: game.pendingRestSite) { _, isUp in
            // The first camp was just resolved (Rest, Descend, or Raid): the
            // tutorial is done, and now is a fair moment to ask for permissions.
            if !isUp && tutorialStepRaw == TutorialStep.firstCamp.rawValue {
                finishTutorial()
            }
        }
        .onChange(of: autoBattle) { _, newValue in
            game.autoBattle = newValue   // keep the model's live flag in sync with the toggle
        }
        .onChange(of: game.currentFloor) { _, floor in
            advanceTutorial(forFloor: floor)
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
                let menuOpen = selectedTab != .battle || showStore || showSettings
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

    // MARK: - Tutorial

    /// Floor-driven tutorial beats (first run only):
    ///   floor 2 → GREED hint · floor 3 → AT RISK hint + a guaranteed drop ·
    ///   floor 5 → a scripted early camp, so the Rest / Descend decision shows
    ///   up in the first minute or two instead of at floor 10.
    private func advanceTutorial(forFloor floor: Int) {
        guard let step = TutorialStep(rawValue: tutorialStepRaw), step != .done else { return }

        if step == .strike && floor >= 2 {
            tutorialStepRaw = TutorialStep.greed.rawValue
        }
        if floor >= TutorialStep.guaranteedDropFloor && !tutorialDropGiven {
            tutorialDropGiven = true
            game.grantTutorialDrop()
        }
        if floor >= TutorialStep.guaranteedDropFloor && tutorialStepRaw == TutorialStep.greed.rawValue {
            tutorialStepRaw = TutorialStep.atRisk.rawValue
        }
        if floor >= TutorialStep.firstCampFloor && tutorialStepRaw < TutorialStep.firstCamp.rawValue {
            tutorialStepRaw = TutorialStep.firstCamp.rawValue
            game.pendingRestSite = true
        }
    }

    private func finishTutorial() {
        tutorialStepRaw = TutorialStep.done.rawValue
        // Ad consent / tracking can start now (GameViewController listens).
        // Notifications are asked later, when they obviously help: the first
        // time the player comes back to a hero who died while they were away.
        NotificationCenter.default.post(name: .tutorialFinished, object: nil)
        Analytics.tutorialCompleted()
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
        case .hero:
            HeroTabView(game: game)
        case .prestige:
            PrestigeTabView(game: game, combatScene: combatScene, onChangeCharacter: { onChangeCharacter(game) })
        case .quests:
            QuestsTabView(game: game)
        case .battle:
            EmptyView()
        }
    }
}
