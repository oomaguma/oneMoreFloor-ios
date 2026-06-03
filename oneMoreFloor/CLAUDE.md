# Claude Code Context — oneMoreFloor

## About the Developer

**Name:** Josh  
**Background:** QA Engineer with iOS UI test experience (Swift, Java, Appium). Self-taught on the Swift/SwiftUI development side — no formal training. Understands coding fundamentals (OOP, inheritance, basic data flow) but benefits from explanations of *why* decisions are made, not just *what* the code does.  
**Role:** Solo technical driver of a three-person LLC building polished iOS apps, with Android planned for the future.

## How to Work with Josh

- **Teach while you build.** Explain reasoning and patterns, especially when something is non-obvious. Frame explanations using concepts Josh already knows (QA, testing, OOP basics).
- **Present options, but give a clear recommendation** with your reasoning. Don't just list trade-offs and leave it open.
- **Be direct.** Josh is engaged and results-oriented — don't pad responses.
- **Comments in code are expected.** Every file should have organized comments (use `// MARK: -` sections in Swift). No scattered one-liners everywhere; no completely uncommented files either.
- **Keep it simple.** Prefer readable, inferrable code over clever abstractions. If something needs three similar lines instead of a helper, write the three lines.
- **No over-engineering.** Don't add features, fallbacks, or abstractions beyond what was asked for.

## Project Overview

**oneMoreFloor** is an idle/auto-battle dungeon crawler for iOS.

- **Language:** Swift / SwiftUI
- **Game engine:** SpriteKit (for combat animations in `SoldierAnimationScene.swift`)
- **Architecture:** `DungeonGame` is the central game state model. `ContentView.swift` / `GameView` owns the UI and drives the game loop via a SwiftUI `.task` that calls `game.tick()` on a timer interval.
- **Monetization:** Google Mobile Ads, UMP (consent), StoreKit (IAP via `StoreManager`)
- **Analytics:** PostHog (`AnalyticsManager`)
- **Persistence:** Custom JSON save/load in `DungeonGame`

## Key Patterns to Know

- The game loop runs in a `.task` on `GameView`, calling `game.tick()` every `game.tickInterval` seconds. The `isFading` flag pauses ticks during floor transition animations.
- `CombatScene` (SpriteKit) is driven entirely by callbacks (`onHeroAttack`, `onMonsterSpawn`, etc.) set up in `GameView.onAppear`. The scene has no direct reference to game state.
- `isGameOver` must be reset to `false` on any path that restarts the run (prestige, revive, restart).
- Prestige resets the current run but preserves `soulShards`, `prestigeUpgrades`, `equippedItems`, and `deepestFloorEver`.
