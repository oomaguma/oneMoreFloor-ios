// TitleScreenView.swift
// The title screen: pixel-art backdrop, floating logo, rising embers,
// and the Continue / New Hero buttons.

import SwiftUI

// MARK: - Title Screen

struct TitleScreenView: View {
    let hasSave: Bool
    let onContinue: () -> Void
    let onNewHero: () -> Void

    @State private var pulse  = false
    @State private var bob    = false
    @State private var bgZoom = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Pixel-art backdrop (crisp, no smoothing) filling the screen.
                Image("title_bg")
                    .resizable()
                    .interpolation(.none)
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(bgZoom ? 1.06 : 1.0)   // slow Ken Burns drift
                    .clipped()

                // Darken the bottom so the buttons stay legible.
                LinearGradient(colors: [.clear, .black.opacity(0.6)],
                               startPoint: .center, endPoint: .bottom)
                    .ignoresSafeArea()

                // Ambient embers rising over the backdrop (purely decorative).
                EmberFieldView(size: geo.size)

                VStack(spacing: 0) {
                    Image("title_logo")
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(maxWidth: geo.size.width * 0.82)
                        .offset(y: bob ? -6 : 6)   // gentle float
                        .shadow(color: .black.opacity(0.55), radius: 0, x: 0, y: 3)
                        .padding(.top, max(48, geo.size.height * 0.09))
                        .background(
                            // Warm glow that gently breathes behind the logo/hero.
                            Circle()
                                .fill(Color(red: 1.0, green: 0.55, blue: 0.2))
                                .frame(width: 220, height: 220)
                                .blur(radius: 80)
                                .opacity(pulse ? 0.28 : 0.15)
                                .offset(y: geo.size.height * 0.10)
                        )

                    Spacer()

                    VStack(spacing: 14) {
                        if hasSave {
                            titleButton("CONTINUE", primary: true, action: onContinue)
                        }
                        // With no save, New Hero is the only path in, so it gets the gold treatment.
                        titleButton("NEW HERO", primary: !hasSave, action: onNewHero)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, max(80, geo.size.height * 0.18))
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                    pulse = true
                }
                withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) {
                    bob = true
                }
                withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) {
                    bgZoom = true
                }
            }
        }
        .preferredColorScheme(.dark)
    .ignoresSafeArea()
    }

    /// A chunky 3D button. `primary` is the gold "go" button; the other is stone.
    private func titleButton(_ label: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.impact(.medium)
            action()
        } label: {
            Text(label)
                .font(Theme.Fonts.display(22))
                .tracking(1.5)
                .foregroundStyle(primary ? Color.black.opacity(0.8) : Theme.Palette.parchment)
                .shadow(color: primary ? .white.opacity(0.35) : .black.opacity(0.85), radius: 0, y: primary ? 1 : 2)
        }
        .buttonStyle(ChunkyButtonStyle(face: primary ? Theme.Palette.gold : Theme.Palette.stoneHi,
                                       lip: primary ? Theme.Palette.goldDeep : .black,
                                       cornerRadius: 16, depth: 6))
        .frame(height: 64)
        .shadow(color: primary ? Theme.Palette.flame.opacity(0.45) : .clear, radius: 18)
    }
}

// MARK: - Title Embers

/// Ambient embers drifting up the title screen. Purely decorative — it never
/// intercepts touches, so the menu buttons underneath stay tappable.
struct EmberFieldView: View {
    let size: CGSize

    var body: some View {
        ZStack {
            ForEach(0..<16, id: \.self) { i in
                EmberView(fieldSize: size, seed: i)
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }
}

struct EmberView: View {
    let fieldSize: CGSize
    let seed: Int
    @State private var rise = false

    // Seed-derived parameters so the embers look organic instead of synced.
    private var startX: CGFloat  { fieldSize.width * CGFloat(seed * 53 % 100) / 100 }
    private var drift: CGFloat   { CGFloat(seed * 37 % 60) - 30 }   // sideways sway
    private var dotSize: CGFloat { CGFloat(2 + seed * 17 % 4) }      // 2…5 px
    private var duration: Double { 6 + Double(seed * 13 % 6) }       // 6…11 s rise
    private var delay: Double    { Double(seed * 29 % 70) / 10.0 }   // staggered start

    var body: some View {
        Circle()
            .fill(Color(red: 1.0, green: 0.64, blue: 0.28))
            .frame(width: dotSize, height: dotSize)
            .blur(radius: 1)
            .opacity(rise ? 0.0 : 0.75)
            .position(x: startX + (rise ? drift : 0),
                      y: rise ? -10 : fieldSize.height + 10)
            .onAppear {
                withAnimation(.easeIn(duration: duration).repeatForever(autoreverses: false).delay(delay)) {
                    rise = true
                }
            }
    }
}
