// Theme.swift
// The game's design system, all in one place.
//
// Before the glow-up, every view hand-rolled its own `Color(red:green:blue:)`
// and `.font(.system(... design: .monospaced))`. That's why the game read like
// a terminal: there was no shared visual language, just a lot of one-offs.
//
// This file is that shared language. Views should reach for `Theme.Palette`,
// `Theme.Fonts`, and the reusable pieces below instead of raw values. The
// payoff: changing the game's whole look (e.g. swapping in a pixel font later)
// becomes a one-line edit here instead of a hunt through 3,000 lines of views.

import SwiftUI

enum Theme {

    // MARK: - Palette
    //
    // A warm, torch-lit dungeon palette. Backgrounds are warm near-blacks (not
    // the old cold blue-grey), so the orange of torches and greed feels at home.

    enum Palette {
        // Surfaces, darkest to lightest.
        static let abyss     = Color(red: 0.045, green: 0.035, blue: 0.055)  // page background
        static let stone     = Color(red: 0.11,  green: 0.09,  blue: 0.10)   // panel fill
        static let stoneHi   = Color(red: 0.17,  green: 0.14,  blue: 0.14)   // panel top highlight
        static let stoneEdge = Color(red: 0.30,  green: 0.24,  blue: 0.20)   // panel border

        // Text.
        static let parchment = Color(red: 0.96, green: 0.90, blue: 0.78)     // primary text
        static let dust      = Color(red: 0.70, green: 0.63, blue: 0.55)     // secondary text
        static let ash       = Color(red: 0.45, green: 0.40, blue: 0.37)     // disabled / hints

        // Currencies.
        static let gold      = Color(red: 1.00, green: 0.80, blue: 0.28)
        static let goldDeep  = Color(red: 0.75, green: 0.50, blue: 0.10)
        static let shard     = Color(red: 0.55, green: 0.85, blue: 1.00)

        // Combat.
        static let blood     = Color(red: 0.92, green: 0.22, blue: 0.22)     // enemy HP, damage
        static let life      = Color(red: 0.35, green: 0.90, blue: 0.45)     // hero HP, heals, rest
        static let lifeDeep  = Color(red: 0.12, green: 0.45, blue: 0.20)
        static let frost     = Color(red: 0.45, green: 0.85, blue: 1.00)     // dodge, shields
        static let warning   = Color(red: 1.00, green: 0.78, blue: 0.20)     // low HP

        // Greed heat ramp: ember -> flame -> inferno. `greedColor(_:)` blends these.
        static let ember     = Color(red: 1.00, green: 0.78, blue: 0.30)
        static let flame     = Color(red: 1.00, green: 0.45, blue: 0.15)
        static let inferno   = Color(red: 0.95, green: 0.15, blue: 0.35)
    }

    // MARK: - Greed heat
    //
    // Greed is the game's identity, so its color *escalates*: a calm amber at
    // ×1.0, a hot orange mid-run, and an angry crimson as you near the cap.
    // `fraction` is 0…1 of the way from ×1.0 to the greed cap.

    static func greedColor(_ fraction: Double) -> Color {
        let f = min(1, max(0, fraction))
        if f < 0.5 {
            return Palette.ember.mix(with: Palette.flame, by: f / 0.5)
        }
        return Palette.flame.mix(with: Palette.inferno, by: (f - 0.5) / 0.5)
    }

    // MARK: - Type
    //
    // Two voices instead of one monospaced drone:
    //   • display + number — Pixelify Sans, a pixel font that matches the
    //     sprite art. Headings, floor numbers, multipliers, button labels.
    //     Paired with `.gameShadow()` it echoes the title logo's hard shadow.
    //   • label + body — friendly rounded system text for everything you
    //     actually *read* (descriptions, stats), where a pixel font gets tiring.
    //
    // The font ships in Theme/Fonts/ (SIL Open Font License, copy alongside)
    // and is registered under UIAppFonts in Info.plist. It's a variable font,
    // so `.weight()` picks Regular…Bold. If it ever fails to load, SwiftUI
    // quietly falls back to the system font — nothing breaks.

    static let pixelFontFamily = "Pixelify Sans"
    /// Pixelify Sans looks smaller than the heavy rounded font it replaced at
    /// the same point size, so sizes are nudged up to keep every existing
    /// layout looking the same weight. One knob instead of editing 200 call sites.
    static let pixelFontScale: CGFloat = 1.12

    enum Fonts {
        static func display(_ size: CGFloat) -> Font {
            .custom(Theme.pixelFontFamily, size: size * Theme.pixelFontScale).weight(.bold)
        }
        static func number(_ size: CGFloat) -> Font {
            // Pixel digits are already fixed-width, so numbers don't jitter
            // as they count up (what .monospacedDigit() did for the old font).
            .custom(Theme.pixelFontFamily, size: size * Theme.pixelFontScale).weight(.bold)
        }
        static func label(_ size: CGFloat) -> Font {
            .system(size: size, weight: .bold, design: .rounded)
        }
        static func body(_ size: CGFloat) -> Font {
            .system(size: size, weight: .medium, design: .rounded)
        }
    }
}

// MARK: - Hard "pixel" shadow
//
// A crisp, zero-blur drop shadow straight down — the same trick the title logo
// uses. It makes plain text look stamped onto the screen like game UI rather
// than floating like app UI.

extension View {
    func gameShadow(_ y: CGFloat = 2) -> some View {
        shadow(color: .black.opacity(0.85), radius: 0, x: 0, y: y)
    }
}

// MARK: - Game Panel
//
// The standard container: a bevelled stone slab. A lighter top edge and a
// darker bottom edge fake a raised, carved surface — the classic RPG menu look.
// `tint` colors the border so a panel can glow with meaning (greed, rest, etc).

struct GamePanel: ViewModifier {
    var tint: Color = Theme.Palette.stoneEdge
    var cornerRadius: CGFloat = 14
    var translucent = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(colors: [Theme.Palette.stoneHi, Theme.Palette.stone],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .opacity(translucent ? 0.82 : 1)
            )
            .overlay(
                // Outer border in the tint color.
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(tint.opacity(0.75), lineWidth: 1.5)
            )
            .overlay(
                // Inner top highlight — the "bevel" that sells the carved look.
                RoundedRectangle(cornerRadius: cornerRadius - 2)
                    .strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.10), .clear],
                                       startPoint: .top, endPoint: .center),
                        lineWidth: 1
                    )
                    .padding(2)
            )
    }
}

extension View {
    func gamePanel(tint: Color = Theme.Palette.stoneEdge,
                   cornerRadius: CGFloat = 14,
                   translucent: Bool = false) -> some View {
        modifier(GamePanel(tint: tint, cornerRadius: cornerRadius, translucent: translucent))
    }
}

// MARK: - Chunky Button
//
// A 3D game button: a colored face sitting on a darker "lip". Pressing it
// slides the face down onto the lip, so the button physically sinks under
// your thumb. This one detail does more to make the game feel like a *game*
// than almost anything else — flat app buttons feel like forms.

struct ChunkyButtonStyle: ButtonStyle {
    var face: Color
    var lip: Color
    var cornerRadius: CGFloat = 16
    var depth: CGFloat = 5

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(LinearGradient(colors: [face, face.mix(with: lip, by: 0.35)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(
                        // Glossy top highlight on the face.
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(
                                LinearGradient(colors: [.white.opacity(0.45), .clear],
                                               startPoint: .top, endPoint: .center),
                                lineWidth: 1.5)
                    )
            )
            // Face slides down onto the lip when pressed.
            .offset(y: pressed ? depth : 0)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(lip)
                    .offset(y: depth)
            )
            .padding(.bottom, depth)
            .animation(.spring(response: 0.15, dampingFraction: 0.6), value: pressed)
    }
}

// MARK: - Game Bar
//
// A framed meter for HP, greed, cooldowns. Two layers of juice:
//   1. A glossy stripe across the top third, so it reads as a solid tube.
//   2. A "ghost" trail: when the value drops, a pale chunk lingers for a beat
//      and then drains away. That lag is what makes a hit *feel* heavy — the
//      same trick fighting games use.

struct GameBar: View {
    let fraction: Double
    let color: Color
    var height: CGFloat = 10
    var showsGhost = true

    // The ghost lags behind `fraction`, catching up after a short delay.
    @State private var ghost: Double = 1

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                // Empty track.
                Capsule().fill(Color.black.opacity(0.55))

                // Ghost trail — only visible while it's ahead of the real value.
                if showsGhost {
                    Capsule()
                        .fill(Color.white.opacity(0.75))
                        .frame(width: max(0, w * min(1, ghost)))
                }

                // The real fill.
                Capsule()
                    .fill(LinearGradient(colors: [color.mix(with: .white, by: 0.25), color],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: max(0, w * min(1, max(0, fraction))))
                    .overlay(alignment: .top) {
                        // Gloss stripe.
                        Capsule()
                            .fill(Color.white.opacity(0.35))
                            .frame(height: max(1, height * 0.22))
                            .padding(.horizontal, 3)
                            .padding(.top, 1.5)
                    }
                    .animation(.easeOut(duration: 0.12), value: fraction)
            }
            .overlay(Capsule().strokeBorder(Color.black.opacity(0.9), lineWidth: 1.5))
        }
        .frame(height: height)
        .onAppear { ghost = fraction }
        .onChange(of: fraction) { old, new in
            if new >= old {
                // Healing or a fresh enemy: no trail, snap straight up.
                ghost = new
            } else {
                // Damage: hold the ghost for a beat, then drain it.
                withAnimation(.easeIn(duration: 0.35).delay(0.25)) { ghost = new }
            }
        }
    }
}
