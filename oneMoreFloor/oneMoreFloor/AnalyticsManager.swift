import Foundation
import PostHog

// Single place that owns all PostHog calls.
// Replace projectToken with your key from posthog.com → Project Settings.
enum Analytics {

    private static let projectToken = "phc_E2cJgzTk5jWWEJrE1B8zp2tKyaMYJHySYnT29jyWJh4"
    private static let host = "https://us.i.posthog.com"

    static func setup() {
        let config = PostHogConfig(projectToken: projectToken, host: host)
        PostHogSDK.shared.setup(config)
    }

    // MARK: - Session

    static func appLaunched() {
        capture("app_launched")
    }

    // MARK: - Progression

    static func bossDefeated(floor: Int, zone: String, bossName: String) {
        capture("boss_defeated", properties: [
            "floor": floor,
            "stage": DungeonGame.stageLabel(floor: floor),
            "zone": zone,
            "boss_name": bossName
        ])
    }

    static func zoneUnlocked(zoneID: String, zoneName: String) {
        capture("zone_unlocked", properties: [
            "zone_id": zoneID,
            "zone_name": zoneName
        ])
    }

    static func heroDied(floor: Int, deepestEver: Int) {
        capture("hero_died", properties: [
            "floor": floor,
            "stage": DungeonGame.stageLabel(floor: floor),
            "deepest_floor_ever": deepestEver
        ])
    }

    static func prestigeCompleted(shardsEarned: Int, totalShards: Int, deepestFloor: Int) {
        capture("prestige", properties: [
            "shards_earned": shardsEarned,
            "total_shards": totalShards,
            "deepest_floor": deepestFloor
        ])
    }

    // MARK: - Economy

    static func upgradePurchased(id: String, name: String, newLevel: Int) {
        capture("upgrade_purchased", properties: [
            "upgrade_id": id,
            "upgrade_name": name,
            "new_level": newLevel
        ])
    }

    static func prestigeUpgradePurchased(id: String, name: String, newLevel: Int) {
        capture("prestige_upgrade_purchased", properties: [
            "upgrade_id": id,
            "upgrade_name": name,
            "new_level": newLevel
        ])
    }

    static func questClaimed(title: String, rewardGold: Int) {
        capture("quest_claimed", properties: [
            "quest_title": title,
            "reward_gold": rewardGold
        ])
    }

    static func itemDropped(rarity: String, slot: String) {
        capture("item_dropped", properties: [
            "rarity": rarity,
            "slot": slot
        ])
    }

    // MARK: - Monetisation

    static func iapPurchased(productID: String) {
        capture("iap_purchased", properties: ["product_id": productID])
    }

    static func offlineSummaryShown(goldEarned: Int, floorsCleared: Int,
                                    deaths: Int, durationSeconds: Double,
                                    goldDoubled: Bool) {
        capture("offline_summary_shown", properties: [
            "gold_earned": goldEarned,
            "floors_cleared": floorsCleared,
            "deaths": deaths,
            "duration_hours": round(durationSeconds / 3600 * 10) / 10,
            "gold_doubled": goldDoubled
        ])
    }

    static func offlineGoldDoubled(goldEarned: Int) {
        capture("offline_gold_doubled", properties: ["gold_earned": goldEarned])
    }

    // MARK: - Onboarding

    static func characterSelected(characterID: String) {
        capture("character_selected", properties: ["character_id": characterID])
    }

    /// The first-session tutorial finished (first camp resolved). Compare against
    /// character_selected to see how many new players make it through.
    static func tutorialCompleted() {
        capture("tutorial_completed")
    }

    /// Each step of the first-session tutorial as the player reaches it. Line
    /// these up in a PostHog funnel (strike → greed → at_risk → first_camp →
    /// tutorial_completed) to see exactly where new players drop off.
    static func tutorialStepReached(_ step: String) {
        capture("tutorial_step", properties: ["step": step])
    }

    // MARK: - Push Your Luck (rest sites + raids)

    /// The core decision of the game: at a camp, did the player bank or push?
    /// `choice` is "rest", "descend" or "raid". Greed and pot tell us how
    /// brave players are — if nobody ever descends, the gamble isn't tempting.
    static func restSiteChoice(_ choice: String, floor: Int, greed: Double, pot: Int) {
        capture("rest_site_choice", properties: [
            "choice": choice,
            "floor": floor,
            "greed": round(greed * 10) / 10,
            "pot": pot
        ])
    }

    /// The raid briefing funnel: opened → started, or opened → backed out.
    /// Split by `danger` to see whether the danger rating scares players off.
    static func raidBriefingOpened(floor: Int, danger: String) {
        capture("raid_briefing_opened", properties: ["floor": floor, "danger": danger])
    }

    static func raidBriefingBackedOut(floor: Int, danger: String) {
        capture("raid_briefing_backed_out", properties: ["floor": floor, "danger": danger])
    }

    static func raidStarted(floor: Int, danger: String, blessings: Int) {
        capture("raid_started", properties: [
            "floor": floor,
            "danger": danger,
            "blessings": blessings
        ])
    }

    /// How a raid ended: "cleared", "escaped" or "lost". `wave` is the wave the
    /// player escaped after (0 otherwise). If almost everyone escapes after
    /// wave 1, the last waves are too scary (or not worth enough).
    static func raidEnded(outcome: String, wave: Int, floor: Int, shards: Int, blessings: Int) {
        capture("raid_ended", properties: [
            "outcome": outcome,
            "escaped_after_wave": wave,
            "floor": floor,
            "shards": shards,
            "blessings": blessings
        ])
    }

    // MARK: - Notifications

    /// The "Want a heads-up next time?" panel appeared on the offline summary.
    static func notificationAskShown() {
        capture("notification_ask_shown")
    }

    /// The player tapped NOTIFY ME, and what they then said to iOS's dialog.
    static func notificationAskAnswered(granted: Bool) {
        capture("notification_ask_answered", properties: ["granted": granted])
    }

    // MARK: - Hall of the Fallen

    /// The player opened the share sheet for a tombstone. ShareLink doesn't
    /// report whether they actually sent it, so this counts intent, not sends.
    /// `source` is "game_over" or "hall".
    static func fallShareTapped(source: String, floor: Int) {
        capture("fall_share_tapped", properties: [
            "source": source,
            "floor": floor
        ])
    }

    // MARK: - Private

    private static func capture(_ event: String, properties: [String: Any]? = nil) {
        PostHogSDK.shared.capture(event, properties: properties)
    }
}
