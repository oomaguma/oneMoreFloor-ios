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

    // MARK: - Private

    private static func capture(_ event: String, properties: [String: Any]? = nil) {
        PostHogSDK.shared.capture(event, properties: properties)
    }
}
