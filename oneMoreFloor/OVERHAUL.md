# oneMoreFloor — The Overhaul

**Status:** Phases 1 & 2 complete & compiling clean (2026-06-22), under active playtest/tuning. Phase 3 (UI overhaul + onboarding + ASO) and Phase 4 (monetization) not started; some Phase 4 rewarded-ad placements landed early.
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

### Phase 3 — UI overhaul + onboarding + the App Store listing
- Full visual polish pass on every screen.
- A first-session tutorial that teaches tap + the push-your-luck choice in <60s.
- ASO: new icon, screenshots that show the greed tension, keyword/title optimization. (Partly outside the code.)

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
- `ContentView.swift` — `GameView` owns the loop (`.task` calling `tick()`) and the battle UI.

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
