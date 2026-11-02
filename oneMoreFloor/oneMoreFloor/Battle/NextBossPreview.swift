// NextBossPreview.swift
// The "something's coming" plate in the battle header: a blacked-out
// silhouette of the zone's boss, a floor countdown, and a hint of its trick.
// It gets more urgent (red glow, pulsing) as the boss floor gets close.

import SwiftUI
import SpriteKit

// MARK: - Next Boss Preview

struct NextBossPreview: View {
    let game: DungeonGame

    /// Within this many floors, the plate starts glowing red and pulsing.
    private let closeRange = 3

    var body: some View {
        let left = game.floorsUntilBoss
        // Hidden on the boss floor itself — the boss is right there on screen.
        if left > 0, let boss = game.nextBossEnemy {
            let isClose = left <= closeRange
            HStack(spacing: 8) {
                BossSilhouette(enemy: boss, isClose: isClose)

                VStack(alignment: .leading, spacing: 1) {
                    Text(left == 1 ? "BOSS NEXT FLOOR" : "BOSS IN \(left)")
                        .font(Theme.Fonts.label(11))
                        .foregroundStyle(isClose ? Theme.Palette.blood : Theme.Palette.dust)
                        .contentTransition(.numericText())
                    Text(game.nextBossGimmick.teaser)
                        .font(Theme.Fonts.body(10))
                        .foregroundStyle(Theme.Palette.dust.opacity(0.8))
                        .lineLimit(1)
                }
            }
            .padding(.leading, 4)
            .padding(.trailing, 10)
            .padding(.vertical, 4)
            .gamePanel(tint: isClose ? Theme.Palette.blood : Theme.Palette.stoneEdge,
                       cornerRadius: 10, translucent: true)
            .animation(.spring(response: 0.4), value: left)
        }
    }
}

// MARK: - Boss Silhouette

/// The boss's first idle frame, filled solid black with a red rim — you can
/// tell its shape, but not quite what it is. Pulses when the boss is close.
private struct BossSilhouette: View {
    let enemy: EnemyType
    let isClose: Bool
    @State private var pulse = false

    var body: some View {
        ZStack {
            if let frame = SpriteFrames.firstFrame(of: enemy.idle) {
                Image(uiImage: frame)
                    .renderingMode(.template)      // every pixel becomes one flat color…
                    .interpolation(.none)          // …and stays crisp pixel art
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.black)
                    // The rim light that makes the black shape readable on a dark panel.
                    .shadow(color: (isClose ? Theme.Palette.blood : Theme.Palette.ash).opacity(0.9), radius: 1.5)
                    .shadow(color: isClose ? Theme.Palette.blood.opacity(pulse ? 0.8 : 0.2) : .clear, radius: 6)
                    .padding(3)
            }
        }
        .frame(width: 38, height: 38)
        .scaleEffect(isClose && pulse ? 1.08 : 1)
        .onAppear { startPulse() }
        .onChange(of: isClose) { _, _ in startPulse() }
    }

    private func startPulse() {
        guard isClose else { pulse = false; return }
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true }
    }
}

// MARK: - Sprite Frames

/// Pulls a single frame out of a monster's sprite sheet so SwiftUI can show
/// it. The sheets live in compiled SpriteKit atlases (UIImage(named:) can't
/// see them), so this reuses the scenes' own `buildFrames` slicer and turns
/// the first frame into a UIImage. Cached: slicing on every redraw is waste.
enum SpriteFrames {
    private static var cache: [String: UIImage] = [:]

    static func firstFrame(of spec: AnimationSpec) -> UIImage? {
        if let hit = cache[spec.imageName] { return hit }
        guard let first = buildFrames(spec).first else { return nil }
        // The monster only fills a small part of its frame (and how small
        // varies per monster), so trim the see-through border before showing it.
        let frame = first.cgImage()
        let image = UIImage(cgImage: trimmedToContent(frame) ?? frame)
        cache[spec.imageName] = image
        return image
    }

    /// Crops away fully transparent rows and columns around the drawing.
    /// Redraws the image into a known RGBA layout so we can read each pixel's
    /// alpha, finds the box that holds every visible pixel, and cuts to it.
    private static func trimmedToContent(_ image: CGImage) -> CGImage? {
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &pixels, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where pixels[(y * width + x) * 4 + 3] > 0 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }   // fully transparent
        // The buffer's rows run top-to-bottom, the same as CGImage cropping.
        return image.cropping(to: CGRect(x: minX, y: minY,
                                         width: maxX - minX + 1, height: maxY - minY + 1))
    }
}
