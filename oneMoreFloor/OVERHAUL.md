# oneMoreFloor — The Overhaul

**Status:** Phases 1 & 2 complete & compiling clean (2026-06-22), under active playtest/tuning. Phase 3 (UI overhaul) in progress on `feature/glow-up` (2026-10-29): design system, battle screen, and every main screen/overlay restyled; Settings, Store, raid, onboarding and retention loops are done (see 3c–3e); ASO is still to do. Phase 4 (monetization) not started; some Phase 4 rewarded-ad placements landed early.
**Goal:** Turn a passive idle game into the push-your-luck climber its title promises.

This is the living design + build spec for the overhaul. It is the source of truth — keep it current as we build. When a mechanic changes in code, change it here too.

---

## 1. Why we're doing this

The game isn't doing well across the *entire* App Store funnel at once — few downloads, fast bounce, weak spend. Those three don't fail independently; they fail in a chain:

- A weak core loop → players bounce → no D1/D7 retention.
- No retained players → no ratings, no word of mouth → discovery (ASO) tanks → few downloads.
- No engaged players → nobody to monetize → flat revenue.

So this is **mostly one root cause cascading**, plus a store-listing gate that's independently closed. Fix the root and two of the three symptoms start healing on their own.

### The root cause

There is no *you* in the loop. Combat is a `Task.sleep(tickInterval)` timer that auto-resolves while the player watches a health bar. There is not a single tap, swipe, or decision during a fight. And advancing a floor is an automatic `currentFloor += 1` that happens *to* the player.

The game is called **One More Floor** — but "should I push one more floor?" should be an agonizing decision, and right now it's not a decision at all. **The title promises a tension the game never delivers.** That's what we're fixing.

---

## 2. The vision: push-your-luck + tap combat

Three pillars, layered onto the systems that already exist (combat scene, gold economy, equipment drops, floor events):

1. **Tap to strike** — the enemy is a tap target. Active play is *faster* than idle, which hooks the first session. Idle/offline still works underneath.
2. **The Greed meter** — a multiplier on gold and loot that climbs every floor you clear without resting. The number that makes "one more floor" tempting.
3. **Banked vs. at-risk gold + the Descend/Rest choice** — gold earned this descent is at risk until you bank it. Push deeper for a bigger pot and higher greed, or rest to lock it in and heal. *That's* the gamble.

---

## 3. Core loop design

### 3.1 Tap combat

- Tapping the enemy performs a **hero strike**: deals `heroAtk` damage, can crit at `heroCritChance` (same rules as an auto-attack). Rate-limited only by how fast a human can tap.
- The **auto-attack continues underneath** on the tick timer. So idle still progresses; active tapping just adds extra strikes → faster kills → faster climbing. This is the proven idle-game hook (Tap Titans / Clicker Heroes): *active is better, idle still works.*
- **Crucial rule: taps never trigger enemy retaliation.** The enemy only counter-attacks on the auto-tick. Tapping is pure bonus DPS with no extra incoming damage — that's the reward for engaging.
- **Juice** (mostly already built): each tap fires `onHeroAttack` (animation), the floating damage number, crit display, and sound. Add a haptic tap (we have `HapticsManager`) and a small scale-pop on the enemy node.

This requires splitting the current `doCombatTick()` into two pieces:
- `heroStrike(source:)` — hero damage → monster, crit, kill rewards, floor advance. Called by **both** the auto-tick and a tap.
- `enemyRetaliate()` — block check, damage → hero. Called **only** by the auto-tick, after the auto strike, if the monster survived.

### 3.2 The Greed meter

- A `greedMultiplier` starts at **1.0** at run start and after every rest.
- It rises **+0.1 per floor cleared** without resting. (Tunable. At a 14-floor streak that's ×2.4.)
- Capped at **×5.0** initially (tunable).
- It multiplies **gold earned** and shifts the **loot-rarity table upward** (deeper greedy runs drop better gear).
- Resets to **1.0** on Rest and on death.

### 3.3 Banked vs. at-risk gold, and the Descend/Rest choice

The stake model — the heart of the overhaul:

- Split the single `gold` value into **`bankedGold`** (safe, spendable on upgrades/shop) and **`atRiskGold`** (earned this descent).
- **At-risk gold is NOT spendable** until banked. This is the key tension lever: you must *rest* to actually use what you've earned — but resting forfeits the greed climb. (If this feels too restrictive in playtest, the fallback is to make it spendable but still wiped on death. Flagged as the #1 tuning question.)
- **Rest** (at a rest site, or the always-available "Rest now" button): `atRiskGold → bankedGold`, heal to full, `greedMultiplier → 1.0`.
- **Descend** (push past a rest site): keep climbing. Greed keeps rising, enemies keep getting harder, the at-risk pot keeps growing.
- **Death:** lose all `atRiskGold`, `greedMultiplier → 1.0`, run resets to floor 1 (as today). **Banked gold, soul shards, prestige upgrades, equipment, and `deepestFloorEver` are all safe** — so death stings without erasing long-term progress.

**Rest-site cadence (initial):** a guaranteed rest site after every boss (floors 10, 20, 30, …), plus an always-available "Rest now" button so the player always has agency. Deeper rest sites get rarer to raise the stakes (tunable).

### 3.4 How it integrates with prestige

Prestige is unchanged: soul shards still come from `deepestFloor`, and prestige resets the run. The greed/banking loop sits *inside* a single run — it's the moment-to-moment tension; prestige remains the long arc. They don't conflict.

---

## 4. Phased plan

### Phase 1 — Core loop transplant (the retention fix) — ✅ COMPLETE (compiles clean; needs playtest/tuning)
The smallest change that fixes the dead first session. Ship it, watch D1/D7 move.
- [x] **1a. Refactor:** enemy HP/ATK boss scaling (`EnemyType.scaledHp/scaledAtk`) and the gold reward (`DungeonGame.goldReward`) extracted into single helpers used by live combat, offline sim, and death estimate.
- [x] **1b. Greed multiplier:** `greedMultiplier` (start 1.0, +0.1/floor, cap 5.0) applied in `goldReward` and the loot-rarity roll (`EquipmentDrop … luck:`), shown in the descent bar, persisted (v9).
- [x] **1c. Split combat:** `doCombatTick()` is now `heroStrike()` + `enemyRetaliate()`; the auto-tick calls both, a tap calls only `heroStrike()`.
- [x] **1d. Tap to strike:** a bottom-screen strike pad (`StrikePadView`, in the thumb's resting zone) → `playerTap()` (guarded by `canTap`), with `Haptics.impact(.light)` and an instant enemy squash-pop (`CombatScene.tapFeedback()`). *(Moved off the enemy sprite — reaching the top of a tall phone was an awkward grip.)*
- [x] **1e. Banking:** `gold` (banked/spendable) + `atRiskGold` (this descent); `rest()` / `descendPastRestSite()`; death/restart/prestige forfeit at-risk + reset greed; rest site after every boss; offline auto-banks; persisted (v9, old saves migrate `gold → banked`).
- [x] **1f. Battle-screen UI:** `DescentBarView` (greed meter + at-risk gold + always-available Rest button) and `RestSiteCardView` (the Descend/Rest decision), combat paused while the decision is open.

> Implementation notes for whoever picks this up next: the live combat path (`heroStrike`/`enemyRetaliate`) is separate from the headless offline sim by design. The greed/at-risk model only changes the *live* path plus an auto-rest at the top of `simulateOffline`. The stake model (at-risk gold is unspendable until banked) is **open tuning question #1** below — change it there if playtest says so.

### Phase 2 — Skill & depth — ✅ COMPLETE (compiles clean; needs playtest/tuning)
- [x] **2a. Active abilities.** Each class has one signature ability on a cooldown, leaning into its identity: damage *bursts* (Soldier/Swordsman/Lancer/Archer/Wizard — implemented as N reused `heroStrike()` calls, so each hit crits and can land the kill), heals (Knight Templar / Priest), and the Knight's "Shield Wall" guard (temporary incoming-damage cut). Data on `CharacterClass.signatureAbility`; runtime (`abilityCooldownRemaining`, `activateAbility()`, guard window) in `DungeonGame`; `AbilityButtonView` above the strike pad. *This is also what finally makes the 8 classes play differently, not just start differently.* Cooldowns/hit-counts are first-draft — tune in playtest.
- [x] **2b. Telegraphed enemy attacks + dodge/block.** Some enemy turns are *heavy*: the enemy telegraphs (scale-pulse + ⚠ glyph + warning haptic) over `windUpTicks` ticks, and the strike pad flips into a "TAP TO DODGE!" button in the same thumb spot. Dodge in the window → negated; miss → `heavyAttackMultiplier`× damage. Bosses telegraph more often (`heavyChanceBoss`). All knobs are constants in `DungeonGame`. *Window length/feel is the #1 thing to tune in playtest — at the fastest attack speed the window is tight.*
- [x] **2c. Boss gimmicks.** Each zone's boss has a signature behavior (`BossGimmick`, assigned per zone, foreground-only): **Enrage** (+50% damage below 40% HP), **Shield** (every 4 turns it blunts your strikes to 35% for 3 hits), **Lifesteal** (every 3 turns it regenerates 8% max HP). The active state shows as a badge under the boss's name; all knobs are constants in `DungeonGame`.

**Tap-zone layout principle (2026-06-22):** the bottom of the battle screen is the player's thumb zone — it holds only intended actions (the strike pad, which doubles as the dodge button; the ability button just above it). Status that's tappable-but-incidental (blessings, consumables) was moved up next to the combat status, and the rest-site / floor-event decision cards now appear *centered* instead of sliding up from the bottom. This prevents a rapid tapper from accidentally opening a sheet, burning a consumable, or triggering an ad.

**Combat model — turn-based (2026-06-22):** playtesting showed the real-time auto-tick + tap blend felt disconnected, and combat ran on behind open menus (no time to manage). Foreground combat is now **turn-based**: each tap is the hero's turn (`playerStrike` → `enemyTurn` responds); the timer no longer auto-attacks in manual mode (it only handles regen + spawning). A heavy telegraph becomes a turn-based choice — **Dodge** (negate it, no attack) or **Strike through** (attack but take the hit). An **Auto-battle toggle** in the header re-enables timer-driven turns for hands-off grinding (`tick(auto:)` → `autoTurn`), and *all* ticking pauses whenever a menu/sheet is open. Background stays the offline auto-sim, unchanged. The old real-time dodge window (`windUpTicks`) is gone — turn-based has no twitch timing.

**QoL (2026-06-22):** the Upgrades sheet shows spendable gold up top (the sheet hides the status bar), and drops auto-equip when they out-score the worn piece, gated by a Settings toggle (default on; scores by raw stats, so it can break a matched set — hence the toggle).

**Prestige rework (2026-06-22):** the original 9 prestige upgrades were all old-idle stats; none touched the new mechanics. Added three that do, appended to the array so existing saves keep their by-index levels: **Soul Anchor** (keep 15%/level of the at-risk pot when you fall, applied in `restart()`), **Avarice** (+1/level greed cap via `effectiveGreedCap`), **Adrenaline** (−10%/level ability cooldowns via `abilityCooldownScale`). Also reframed **Undying Will** (auto-restart) to offline-only and **Battle Hardened** (speed) to "auto-battle & offline speed," since neither affects manual turn-based play.

**Fixes (2026-06-22):** the Auto toggle now actually drives combat — auto-battle state moved onto the `@Observable` model (`game.autoBattle`), mirrored from the toggle, because a long-lived `.task` was reading a stale `@AppStorage` snapshot. And foreground death always shows the revive/restart overlay now, even with Undying Will, so auto-restart no longer skips the Second Wind ad or silently dumps the at-risk pot.

**Idle fallback — tried, then removed (2026-06-22):** an idle fallback briefly auto-took turns after 3s of no tap so the screen wouldn't freeze. But it fired regardless of the Auto toggle, so turning Auto *off* still auto-battled — confusing. Removed: the **Auto toggle is now the sole auto-battle control** (off = pure manual, waits for taps; on = hands-off). Idle progress comes from turning Auto on, or backgrounding the app (offline sim). Lesson: one explicit control beats an implicit one that contradicts it.

### Phase 3 — UI overhaul ("the glow-up") + onboarding + the App Store listing

**Diagnosis (2026-10-29):** the systems were good but the game was *dressed like a settings screen*: five equal-weight bordered cards stacked vertically, monospaced system font everywhere, the (good) pixel art squeezed into a 230pt letterbox, a fifth of the screen spent on an empty strike pad, and greed — the game's identity — shown as a 7pt progress bar.

**Principles:**
- **The dungeon is the screen.** Art runs full-bleed; UI floats over it.
- **One design system.** All color/type/panels/buttons/bars come from `Theme/Theme.swift`. No new raw `Color(red:…)` or `.monospaced` in views.
- **Feel it, don't read it.** Greed heats the screen; hits shake and freeze; the pot bounces.
- **Thumb zone rule still holds:** bottom = intended actions only (ability + STRIKE). REST moved to the *top* so mashing can't bank by accident.
- **Healthy loops only:** no guilt streaks, fake-scarcity timers, or selling greed / at-risk gold for real money.

**3a. Foundation — ✅ done**
- [x] Split the 3,645-line `ContentView.swift` into per-screen files: `Screens/`, `Battle/`, `Overlays/`, `HUD/`, `Navigation/`, `Tabs/` (Xcode synchronized folders pick them up automatically). Code moved verbatim; only `GameTab` / `CustomGameTabBar` lost `private`.
- [x] `Theme/Theme.swift`: warm torch-lit palette, `Theme.greedColor(_:)` heat ramp, rounded heavy display type + `.gameShadow()` (hard pixel drop shadow), `.gamePanel()` bevelled stone panels, `ChunkyButtonStyle` (3D press-down buttons), `GameBar` (glossy meter with a lagging "ghost" damage trail).

**3b. Battle screen — ✅ done (needs playtest)**
- [x] Full-bleed arena: `CombatScene` now uses `.resizeFill` + a `world` container (design space 200 wide, scaled to the view width) with the zone backdrop filling the view and its floor band under the fighters' feet. Fixes the crop/zoom a tall view caused with the old `.aspectFill`.
- [x] Floating HUD: `BattleHeaderView` (floor, zone, **personal-best marker** "BEST 14 · 2 to go" / "NEW BEST" once your record is floor 5+), `GreedGaugeView` (flame + heat-colored multiplier + at-risk pot + REST), `VersusBarsView` (fighting-game HP bars draining toward the center).
- [x] Tap-anywhere-to-strike on the open dungeon, plus a chunky STRIKE button beside a square ability button with a draining cooldown shade. Heavy telegraph splits STRIKE into DODGE / STRIKE and disables tap-anywhere (the choice must be deliberate) with a pulsing `HeavyWarningView`.
- [x] Juice: greed heat vignette + embers scale with greed; screen shake on crits/death; red edge flash on hero hurt; crit hit-stop (`CombatScene.hitStop`); outlined heavy damage numbers; pot bounce.

**3c. Screen restyles**
- [x] Title buttons → chunky (gold primary).
- [x] Tab bar → stone/gold theme with glowing selected icon.
- [x] Upgrades → icon tiles per stat, level badges, gold chunky buy buttons.
- [x] Rest site card → pot as the headline number, chunky DESCEND / REST / RAID.
- [x] Game over → "YOU FELL / on floor N", pot as headline, chunky Second Wind / Restart.
- [x] **Token migration (pass 2):** every monospaced system font in the app → `Theme.Fonts`; cold blue-grey fills → stone palette (incl. Settings, Store, Raid).
- [x] Character select → atmospheric backdrop, role-colored pedestal glow per hero, equal-height cards.
- [x] Overlays (offline summary, boss victory, zone unlock, item/blessing banners) → `.gamePanel`, chunky buttons, palette tokens.
- [x] Items → gear row pinned to natural height (was ballooning to ~340pt), ghosted gear-art empty slots (the weapon slot's SF Symbol "sword" doesn't exist, so it showed nothing), chunky sell/optimize.
- [x] Quests → display header, themed gold/green progress bars. Prestige → chunky PRESTIGE / RETIRE.
- [x] Floor-event cards → centered glowing icon, category tag, display title, shrine cost line ("Costs 40 · you have 52", red when short), chunky choice buttons. The curse category is labelled **GAMBLE** (they're optional 50/50s, not something that already happened).
- [x] Quests → claimable first / claimed last, icon tile per quest type, gold progress bars, pulsing chunky CLAIM; Daily Champion moved to the top as a bonus card. Fixed: its progress bar always drew full — now claimed / total.
- [x] **Hand-polish (2026-10-30):**
  - Settings and Store dropped their stock navigation bars for a display-font title and `.gamePanel` cards. Settings rows have tinted icon tiles and gold toggles.
  - The Store leads with an honest "Support the game" header, tints each card per product, uses chunky gold price buttons and an OWNED badge, and has a close button.
  - Zone icons moved from Unicode glyphs (▪ ✦ ◆…, which drew a stray black square beside "Entrance") to SF Symbols.
  - `MapView` was dead code (never shown anywhere) and was deleted rather than restyled.
- [x] PRESTIGE now asks for confirmation (it resets the run; Retire already did).
- [x] **Dailies cut from 12 to 3** (2026-10-29): one easy, one medium, one stretch per day (`DungeonGame.questTiers`), chosen deterministically from the date with no repeated quest type. Multi-hour goals (350 kills, 12 bosses, 2,000 gold, floor 40+) were removed from the daily pool. Daily Champion is now "claim all 3" (still 20 ◈). Covered by `oneMoreFloorTests/DailyQuestTests.swift` across every day of 2026. Note: on update day, players mid-day see their list change once (old ids drop out).
- [x] **Pixel font** (2026-10-30): Pixelify Sans (SIL OFL; `Theme/Fonts/`, registered in `UIAppFonts`, license text bundled, credited in Settings) now drives `Theme.Fonts.display` and `.number`: headings, buttons, names and every big number. `label` / `body` stay rounded system text for readability. `Theme.pixelFontScale` (1.12) makes up for the pixel font looking smaller, so existing layouts kept their weight. Some secondary buttons use `label` and so stay rounded (e.g. WATCH AD next to a pixel CONTINUE); switch them to `display` case by case if the mix bothers you.
- [x] **Merged Upgrades + Items into one HERO tab** (2026-10-30, `Tabs/HeroTab.swift`): an UPGRADES / GEAR picker over the existing pages, remembered between visits. The tab bar is down to four tabs: HERO · BATTLE · PRESTIGE · QUESTS. The pages lost their own titles, since the picker names them. The Codex button now sits on the GEAR page.
- [ ] Hide Prestige until it unlocks: deliberately not done yet. The Prestige tab also holds the Hall of the Fallen and is where raid shards are spent, so hiding it needs a rule that covers those too.

**3c-raid. Raid glow-up**

Diagnosis (2026-10-29): the raid is the game's most interesting gamble on paper (stake blessings + the pot for soul shards) but plays as a short auto-fight — taps are just extra auto-attacks, the class ability / dodge / boss gimmicks are absent, the arena is a 300×160 letterbox, and the rest card says "Win ◈ shards" with no number, so it's a blind bet.

Bugs — ✅ fixed (unit-tested in `oneMoreFloorTests/RaidTests.swift`):
- [x] Reward mismatch: the result screen showed `max(1, floor/5)` shards but `completeRaid` paid `max(5, floor/3)`. Now both read `DungeonGame.raidShardReward`.
- [x] A win silently restored pre-raid HP (raid damage lived only in `RaidScene`). `completeRaid(success:heroHpAfterRaid:)` now carries it back, clamped to 1…max.
- [x] Blessing special effects were ignored in raids — War Surge (splash, labelled "raid only") did nothing anywhere. `RaidScene` now applies War Surge splash, Thorn Mantle reflection, and Blood Rush kill-heals with the dungeon's formulas.
- [x] Raid crits used the class base chance; now `game.heroCritChance` (includes the legacy bonus).
- [x] Blessing formulas now live once in `BlessingCombat` (FloorEvents.swift), shared by dungeon and raid combat, with unit tests in `oneMoreFloorTests/BlessingCombatTests.swift` (incl. War Surge target selection via `RaidScene.splashTarget`).
- [x] Seen in the simulator via the new DEBUG launch arguments (`Debug/DebugLaunch.swift`: `-debugRaid <floor>`, `-debugBlessings YES`): War Surge splash numbers visibly land on a second enemy.

Raid playtest findings (2026-10-29, fresh Soldier, no upgrades, floor 10, full HP):
- **Raids are close to unwinnable at their first opportunity.** No blessings: died mid-wave 1. All three special blessings: died early in wave 2. Raid enemies used full single-fight scaling but arrive 3–5 at a time. Blessings help (+1 wave), so the earlier worry that they'd make raids "easy" doesn't hold at this depth.
- [x] **Raid tuning — first draft shipped.** Knobs are static constants at the top of `RaidScene` (unit-tested in `RaidTests`): enemies get **45% HP / 55% ATK** of a normal floor enemy, waves are **2-3-4** (was 3-4-5), and the breather between waves heals **15%** of max HP. Chosen with `Tools/raid_balance_sim.py` (Monte Carlo of the scene's timings, calibrated against two real runs). The first real raid is floor 11 (Crypts), right after the floor-10 boss. Fresh Soldier there:

  - Entering at full HP: AUTO only 0% · tapping ~2/s 96% · tapping ~3/s 100% · AUTO + all three blessings 87%.
  - Entering at 60% HP: AUTO only 0% · tapping ~2/s 52% · tapping ~3/s 100% · AUTO + all three blessings 57%.

  Before tuning, every column was 0%. Design intent: idling loses, skill wins, and staking blessings pays off. Verified in the simulator: AUTO-only now dies in wave 3 (was wave 1). Open question: the jump from ~1 to ~2 taps/s is a steep cliff — revisit once the tap-to-target / ability ideas land.
- [x] **Quit-to-escape exploits — fixed.** (1) `isRaidActive` / `pendingRestSite` weren't saved, so force-quitting a losing raid kept the pot and blessings. (2) Backgrounding 10s+ mid-raid ran the offline "make camp" sim, which banked the pot. Now both are saved (SaveData v10); a fresh launch with a saved raid resolves it as a loss and shows a "Raid abandoned" alert listing what was lost; a merely-backgrounded raid keeps running and skips the offline sim; a pending rest-site choice reappears after relaunch. Tested in `oneMoreFloorTests/SaveStateTests.swift` and verified in the simulator.
- [x] The failure screen now lists only what was actually lost (it used to claim "All blessings lost" with none).

Raid glow-up (2026-10-29):
- [x] **Raid briefing** (`RaidBriefingView` in DecisionCards.swift): the rest card's RAID… button opens it first — zone, wave layout (2 / 3 / 3+boss), prize (+N ◈ + boss-tier loot, escape payouts), what's at stake (blessing icons + pot), and a DANGER read (`DungeonGame.raidDanger`, a closed-form estimate on auto-attack) with a hint that matches the rating. BEGIN RAID or BACK.
- [x] **Cash out between waves**: after waves 1 and 2 the scene pauses (`RaidScene.onWaveCleared` / `continueToNextWave()`); ESCAPE pays `raidEscapeShare` (25% / 50% of the full reward) and keeps blessings + pot (`DungeonGame.escapeRaid`), PRESS ON risks both for the full prize.
- [x] **Visual pass**: `RaidScene` uses the same `resizeFill` + `world` layout as CombatScene (enemies walk in from off-screen); `RaidView` runs it full-bleed via the shared `ArenaSceneView`, with wave pips (crown = boss wave), a stakes row, a hero HP panel, "WAVE n" / "BOSS WAVE" banners, shake on crits and the boss wave, red hurt flash, outlined damage numbers, crit hit-stop, chunkier enemy HP bars.
- [x] **Tap-to-target**: tapping on/near an enemy focuses it (gold ring underfoot); the hero hits the focused enemy first while it's in range.
- [x] **Rewards**: `raidShardReward` now scales with greed; a full clear also rolls boss-tier loot (`EquipmentDrop.rollBoss`), shown on the result screen in its rarity color.
- [x] **Result screen** reads `DungeonGame.raidOutcome` (cleared / escaped / lost, shards, loot, what was lost). The raid resolves the instant it ends — Continue only dismisses — so closing the app on the result screen can't count as abandoning it.
- [ ] Still to do: class ability + heavy-attack dodges inside raids; a mid-wave Retreat at low HP; raid trophies for a collection codex. No paid raid entries or energy systems.

**3d. Onboarding (FTUE) — ✅ done (2026-10-29)**
- [x] The text-wall `IntroCardView` (with its stale "auto-battles on its own" copy) is gone. `Onboarding/Tutorial.swift` drives in-the-moment `CoachBubble`s through a persisted `TutorialStep` (strike → greed → atRisk → campAhead → firstCamp → done): **TAP TO STRIKE** over the STRIKE button the moment an enemy is up; **GREED RISING** under the gauge on floor 2; **GOLD AT RISK** on floor 3 (each advances on GOT IT or by reaching the next beat).
- [x] Scripted first run: a guaranteed boss-tier drop on floor 3 (`DungeonGame.grantTutorialDrop`) and an early camp on floor 5 with a one-line explainer of Rest vs Descend (raid + ad buttons hidden). No random floor events until the tutorial is done (one fired on floor 2 on top of the greed hint in testing).
- [x] The first enemy spawns immediately on entering the battle screen (`immediateSpawn` in onAppear) — a fresh run used to open on ~4s of "…".
- [x] UMP consent + ATT (was at launch in `GameViewController`) now wait for the tutorial's first camp (`.tutorialFinished`). Returning players (tutorial done, or saw the old intro) are unaffected. Verified on a clean install: zero prompts until after the first REST.
- [x] Notification permission (was at launch in `AppDelegate`) moved to where it obviously helps: the "while you were away" summary after the hero **died while the player was away**. A soft ask ("Want a heads-up next time your hero falls?" + NOTIFY ME) appears only while iOS has never asked (`NotificationManager.canAskForPermission()`); the real iOS dialog only on NOTIFY ME, so a "no" to us doesn't burn the one-time system prompt. Players who never die offline are never asked (Settings has the toggle). Verified both paths in the simulator. DEBUG: `-debugOfflineDeath YES` fakes the summary.
- [x] Death notification softened from "Your hero has fallen!" to "<Hero> fell in the dungeon — banked gold and upgrades are safe" (engagement chart: no guilt mechanics).
- [x] `Analytics.tutorialCompleted()` → PostHog `tutorial_completed`; compare with `character_selected` for the funnel.

**3e. Retention loops (from the engagement-loop brainstorm)**
- [x] **Hall of the Fallen** (2026-10-29, `Legacy/`): every run that ends in death (recorded on RESTART; a Second Wind revive doesn't count) is kept as a `FallenHero` — hero, floor, gold lost, greed, slayer, date — under its own UserDefaults key so "New Hero" doesn't wipe it (newest 50). Shown as a section in the Prestige tab (deepest fall crowned; tap for the tombstone card). The killer is saved with the run (SaveData v11 `lastSlayer`) so a relaunch still says "slain by X". Tests: `HallOfTheFallenTests`.
- [x] **Shareable death card**: SHARE YOUR FALL on the game-over screen (and SHARE on each Hall entry) sends the tombstone as a PNG via the system share sheet, rendered only when shared (`FallenCardImage: Transferable`).
- [x] **Bestiary + gear codex** (2026-10-30, `Legacy/Codex.swift` + `CodexViews.swift`): a CODEX button (with overall found/total) on the Hero tab's GEAR page opens two pages. **Bestiary:** every zone boss and every monster type, shown as a black silhouette with "???" until slain, then in full color with its name and kill count. Undiscovered bosses say which floor they wait on; monsters say which zones they live in. **Gear:** every gear piece with five rarity pips that fill in its rarity color as you find each version (10 pieces × 5 rarities = 50). Kills are recorded live and in the offline sim, and drops count even when auto-sold. The codex has its own UserDefaults key (it survives New Hero) and is written in `save()`, not on every kill. Gear a player already owns counts on first load, so returning players don't start at zero. Tests: `CodexTests`.
- [x] **Loot reveal** (2026-10-30, `ItemDropBanner` in RunOverlays.swift): every drop pops its icon out of a burst of its rarity color, a shine sweeps the card, and the headline scales with rarity (ITEM FOUND → RARE DROP! → LEGENDARY!!). Epic and Legendary add spinning rays, a stronger glow and 6s on screen instead of 4. The haptic also scales with rarity, from a light tap for Common to a success buzz for Epic and Legendary. An EQUIPPED / TO BAG tag says where the item went. It stays a non-blocking banner because drops are frequent in an idle loop. DEBUG: `-debugDrop <rarity>`.
- [x] **Next-boss preview** (2026-10-30, `Battle/NextBossPreview.swift`): a plate under the floor counter shows the zone boss as a black silhouette (its first idle frame, trimmed to the drawing and template-filled), a countdown (BOSS IN n / BOSS NEXT FLOOR) and a one-line hint of its gimmick (`BossGimmick.teaser`). Within 3 floors it turns red and pulses; it hides on the boss floor itself. Model: `nextBossFloor`, `floorsUntilBoss`, `nextBossEnemy`, `nextBossGimmick`. Tests: `NextBossTests`.
- [ ] Rare surprise events (mimic, golden goblin, merchant).
- [ ] Later: daily seeded dungeon with a Game Center board.

**3e½. Analytics for the new features — ✅ done (2026-10-30, `AnalyticsManager.swift`)**
So the glow-up can be judged by numbers, not vibes. Every new PostHog event and what it answers:
- [x] `tutorial_step` (`step`: greed / atRisk / campAhead / firstCamp) plus the existing `character_selected` → `tutorial_completed` make up the **FTUE funnel**, showing which beat loses new players. The first step (strike) is where every run starts, so `character_selected` stands in for it.
- [x] `rest_site_choice` (`choice`: rest / descend / raid, with `floor`, `greed`, `pot` logged *before* the choice resets them) answers **is the gamble tempting?** If nearly everyone rests, descending isn't worth it.
- [x] `raid_briefing_opened` → `raid_started` / `raid_briefing_backed_out` (with `danger`) shows **whether the danger rating scares players off**.
- [x] `raid_ended` (`outcome`: cleared / escaped / lost, `escaped_after_wave`, `shards`, `blessings`) answers **are raids winnable, and is escaping too attractive?** A raid abandoned by quitting the app logs as `lost`.
- [x] `notification_ask_shown` → `notification_ask_answered` (`granted`) shows **whether the soft ask converts**.
- [x] `fall_share_tapped` (`source`: game_over / hall) counts **interest in the death card**. ShareLink can't report a completed share, so this counts taps that open the sheet, not sends.
- No personal data: only game numbers and button choices. The hero name is never sent.

**3f. ASO**
- [ ] New screenshots that show the greed tension (the new battle screen is the hero shot), keyword/title pass. (Partly outside the code.)

### Phase 4 — Monetization rework
Mostly waits until retention is proven. **Principle: rewarded / opt-in only — no forced interstitials, which would worsen the very retention we're fixing.**

Started early (2026-06-22, by request — both rewarded, both reinforce the loop):
- [x] **Second Wind** — the game-over screen now surfaces the at-risk pot + greed, and the revive ad is reframed as "keep your gold." Reuses the existing `reviveAd` unit, so no AdMob setup needed.
- [x] **Double pot** — a rewarded "double your at-risk pot" button on the rest-site card (`bonusAd` in `AdManager`). Hidden for Remove Ads buyers. Release ad-unit ID is a `TODO(Josh)` to create in AdMob; debug uses Google's test ID so it works immediately.

Still to do:
- Boss-victory double-gold (rework the overlay's 4s auto-dismiss / tap-to-dismiss first).
- A descent-boost ad at the rest site (watch → next stretch starts with +greed or a guaranteed rare).
- Re-tune "Remove Ads" and "Night Watch" around the banking loop.

---

## 5. Technical notes

### Files in play
- `DungeonGame.swift` — the model. All combat/economy/state changes live here.
- `CombatScene` (`SoldierAnimationScene.swift`) — callback-driven; add the tap target + tap juice.
- `Screens/GameView.swift` — `GameView` owns the loop (`.task` calling `tick()`), wires combat callbacks, hosts overlays. The battle UI lives in `Battle/BattleViews.swift`; shared styling in `Theme/Theme.swift`.

### The duplicated-combat-logic problem (fix in 1a)
Combat rules are currently written **three times**: `doCombatTick()` (live), `simulateOffline()` (offline), and `estimatedSecondsUntilFirstDeath()` (death-notification timing). Any combat change must touch all three or they silently drift. Phase 1a extracts the shared *formulas* (enemy scaling, gold reward) into single helpers so the rules live in one place. We deliberately do **not** merge the whole loop — the offline sim is intentionally headless/simplified (no callbacks, no crit) for speed. We only de-duplicate the formulas, not the orchestration. (Keep it simple — no over-engineering.)

### Persistence
`SaveData` is versioned with optional fields for backward compatibility. New state (`greedMultiplier`, `bankedGold`, `atRiskGold`) is added as **optional** fields so existing saves load cleanly. Migration: an old save with a single `gold` value maps to `bankedGold = gold`, `atRiskGold = 0`.

### Offline sim under the new model
Offline play is the idle baseline (no taps). Decision: the offline sim **auto-rests at every rest site** — it banks conservatively rather than gambling on the player's behalf. So offline can't lose at-risk gold to a death it didn't choose. (Tunable; the alternative is an "auto-push" prestige upgrade later.)

---

## 6. Open questions / tuning knobs

These need playtesting — don't treat the numbers above as final:
1. **Is at-risk gold spendable?** (Recommended: no — it's the core tension. Fallback: yes-but-wiped-on-death if it frustrates.)
2. **Greed curve:** +0.1/floor and ×5.0 cap are guesses. Tune against how a real run feels.
3. **Rest-site cadence:** every boss to start. Should deep floors really get rarer rest sites?
4. **Tap damage:** flat `heroAtk` per tap to start. May need a combo/Focus system (Phase 2) if mashing feels mindless.
