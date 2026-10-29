// Tutorial.swift
// The first-session tutorial: teach by doing, not by reading.
//
// The old onboarding was a full-screen wall of text shown before the player
// had touched anything (and part of it was out of date). Players skim those
// and bounce. Instead, small coach bubbles appear *in the moment* — "tap to
// strike" while an enemy is in front of you, GREED once it actually starts
// rising, AT RISK once there's gold to lose — and the first run is lightly
// scripted so the game's core decision (Rest or Descend?) shows up within the
// first minute or two instead of at floor 10.
//
// It also gates the system permission prompts (notifications, ad consent /
// tracking). Asking before the player has had any fun is a classic way to
// get a "Don't Allow" — and to lose the player. They're asked right after the
// first rest-site decision instead.

import SwiftUI

// MARK: - Steps

/// Where the player is in the tutorial. Stored as an Int in UserDefaults so
/// it survives relaunches and is shared across heroes (you only learn once).
enum TutorialStep: Int {
    /// First enemy in front of you: tap to strike.
    case strike = 0
    /// Reached floor 2: greed starts climbing.
    case greed = 1
    /// Gold has started piling up: it's at risk until banked.
    case atRisk = 2
    /// Hints done; waiting to reach the scripted early camp on floor 5.
    case campAhead = 3
    /// The scripted early rest site is up: make the first Rest / Descend call.
    case firstCamp = 4
    /// Tutorial finished. (Also set for players who saw the old intro.)
    case done = 99

    static let storageKey = "com.oneMoreFloor.tutorialStep"

    /// Floors where the first run is scripted (first run only).
    static let guaranteedDropFloor = 3
    static let firstCampFloor      = 5

    /// UserDefaults key: has the first-run guaranteed drop been handed out?
    static let dropGivenKey = "com.oneMoreFloor.tutorialDropGiven"

    /// The persisted step, read outside SwiftUI (e.g. GameViewController).
    static var current: TutorialStep {
        TutorialStep(rawValue: UserDefaults.standard.integer(forKey: storageKey)) ?? .strike
    }
}

extension Notification.Name {
    /// Posted once when the tutorial finishes, so the ad-consent / tracking
    /// flow (owned by GameViewController) can start at a friendly moment.
    static let tutorialFinished = Notification.Name("com.oneMoreFloor.tutorialFinished")
}

// MARK: - Coach Bubble

/// A small floating hint: icon, one or two short lines, and (for steps that
/// aren't finished by an action) a GOT IT button. Only the button takes taps,
/// so the bubble never blocks the dungeon's tap-to-strike area.
struct CoachBubble: View {
    let icon: String
    let title: String
    let message: String
    var tint: Color = Theme.Palette.gold
    /// Arrow direction: points at what the bubble is talking about.
    var pointsUp = false
    var onGotIt: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            if pointsUp { arrow.rotationEffect(.degrees(180)) }
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(tint)
                    .symbolEffect(.bounce, options: .repeat(.periodic(delay: 1.2)))
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Fonts.display(15))
                        .foregroundStyle(tint)
                        .gameShadow(1)
                    Text(message)
                        .font(Theme.Fonts.body(13))
                        .foregroundStyle(Theme.Palette.parchment)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if let onGotIt {
                    Button("GOT IT", action: onGotIt)
                        .font(Theme.Fonts.label(12))
                        .foregroundStyle(Color.black.opacity(0.8))
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(Capsule().fill(tint))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .gamePanel(tint: tint.opacity(0.85), cornerRadius: 14, translucent: true)
            .allowsHitTesting(onGotIt != nil)
            if !pointsUp { arrow }
        }
        .shadow(color: tint.opacity(0.35), radius: 12)
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    /// A small triangle under (or over) the bubble.
    private var arrow: some View {
        Triangle()
            .fill(tint.opacity(0.85))
            .frame(width: 16, height: 8)
            .allowsHitTesting(false)
    }
}

/// Downward-pointing triangle for the bubble's arrow.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
