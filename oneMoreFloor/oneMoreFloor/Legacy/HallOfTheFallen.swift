// HallOfTheFallen.swift
// A memorial of every run that ended in death.
//
// Why: death used to be a pure loss — the run vanished. Remembering each
// fallen hero turns it into a story ("Ser Soldier fell on floor 23 carrying
// 1,240 gold at ×3.4 greed") and gives players something to look back on and
// share (engagement chart: identity + investment, and social for the card).
//
// Stored under its own UserDefaults key, NOT inside the run save: "New Hero"
// wipes the run save, and a memorial that disappears when you start over
// would defeat the point.

import Foundation

// MARK: - Fallen Hero

/// One ended run, captured at the moment the player accepts the death (RESTART).
struct FallenHero: Codable, Identifiable, Equatable {
    var id = UUID()
    let heroName: String
    let characterID: String
    let floor: Int
    /// At-risk gold lost with the run (after any Soul Anchor salvage).
    let goldLost: Int
    let greed: Double
    /// The enemy that landed the final blow; nil when it happened while away.
    let slainBy: String?
    let date: Date

    /// "slain by a Skeleton" / "fell while you were away".
    var causeLine: String {
        if let slainBy, !slainBy.isEmpty { return "slain by \(slainBy)" }
        return "fell while you were away"
    }
}

// MARK: - Store

enum HallOfTheFallen {
    static let storageKey = "com.oneMoreFloor.hallOfTheFallen"
    /// Keep the most recent runs; older ones fall off the end.
    static let capacity = 50

    /// All recorded falls, newest first.
    static func load() -> [FallenHero] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let list = try? JSONDecoder().decode([FallenHero].self, from: data)
        else { return [] }
        return list
    }

    /// Adds a fall to the front of the list (trimming to `capacity`) and saves.
    @discardableResult
    static func record(_ fall: FallenHero) -> [FallenHero] {
        let list = Array(([fall] + load()).prefix(capacity))
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        return list
    }

    /// Wipes the memorial (tests only).
    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
