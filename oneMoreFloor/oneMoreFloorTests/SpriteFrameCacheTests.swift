//
//  SpriteFrameCacheTests.swift
//  oneMoreFloorTests
//
//  buildFrames renders a whole sprite sheet offscreen, which profiling showed
//  happening on every enemy spawn. It now caches by sheet; these tests make
//  sure a second request reuses the first result instead of re-rendering.
//

import Testing
import SpriteKit
@testable import oneMoreFloor

@MainActor
struct SpriteFrameCacheTests {

    @Test func theSameSheetIsOnlyBuiltOnce() {
        let spec = EnemyType.skeleton.idle
        let first  = buildFrames(spec)
        let second = buildFrames(spec)
        #expect(first.count == spec.frameCount)
        // Same texture objects back = it came from the cache.
        #expect(first.first === second.first)
    }

    @Test func differentSheetsGetTheirOwnFrames() {
        let idle = buildFrames(EnemyType.skeleton.idle)
        let hurt = buildFrames(EnemyType.skeleton.hurt)
        #expect(idle.first !== hurt.first)
    }
}
