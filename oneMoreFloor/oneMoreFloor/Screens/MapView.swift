// MapView.swift
// The zone map: every zone as a node, locked or unlocked.

import SwiftUI

// MARK: - Map

struct MapView: View {
    let game: DungeonGame

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(game.currentZone.icon)  \(game.currentZone.name)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                Spacer()
                if game.deepestFloorEver > 0 {
                    Text("BEST: \(DungeonGame.stageLabel(floor: game.deepestFloorEver))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.75))
                }
            }
            .padding(.horizontal, 20)

            GeometryReader { geo in
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(Array(DungeonGame.zones.enumerated()), id: \.element.id) { idx, zone in
                                ZoneNodeView(
                                    zone: zone,
                                    isCurrent: game.currentZone.id == zone.id,
                                    isPast: zone.maxFloor != nil && game.currentFloor > zone.maxFloor!,
                                    everReached: game.deepestFloorEver >= zone.minFloor
                                )
                                .id(zone.id)
                                if idx < DungeonGame.zones.count - 1 {
                                    Rectangle()
                                        .fill(zone.maxFloor != nil && game.currentFloor > zone.maxFloor!
                                              ? Color(white: 0.38) : Color(white: 0.18))
                                        .frame(width: 16, height: 2)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)
                        .frame(minWidth: geo.size.width, alignment: .center)
                    }
                    .onChange(of: game.currentZone.id) { _, id in
                        withAnimation(.easeInOut(duration: 0.5)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }
            .frame(height: 88)
        }
        .padding(.vertical, 10)
    }
}

struct ZoneNodeView: View {
    let zone: Zone
    let isCurrent: Bool
    let isPast: Bool
    let everReached: Bool

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(circleFill)
                    .frame(width: 40, height: 40)
                    .shadow(color: isCurrent ? Color(red: 0.40, green: 0.68, blue: 1.00).opacity(0.6) : .clear,
                            radius: 8)
                Circle()
                    .stroke(borderColor, lineWidth: isCurrent ? 2.5 : 1.5)
                    .frame(width: 40, height: 40)
                Text(zone.icon)
                    .font(.system(size: 18, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(iconOpacity))
            }
            Text(zone.shortName)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(isCurrent ? Color.white : Color.white.opacity(textOpacity))
                .multilineTextAlignment(.center)
                .frame(width: 54)
            Text("Fl.\(zone.minFloor)\(zone.maxFloor.map { "-\($0)" } ?? "+")")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.30))
        }
    }

    private var circleFill: Color {
        if isCurrent   { return Color(red: 0.12, green: 0.28, blue: 0.62) }
        if isPast      { return Color(white: 0.22) }
        if everReached { return Color(white: 0.12) }
        return Color(white: 0.08)
    }

    private var borderColor: Color {
        if isCurrent   { return Color(red: 0.45, green: 0.72, blue: 1.00) }
        if isPast      { return Color(white: 0.50) }
        if everReached { return Color(white: 0.28) }
        return Color(white: 0.15)
    }

    private var iconOpacity: Double {
        if isCurrent || isPast { return 1.0 }
        if everReached          { return 0.55 }
        return 0.22
    }

    private var textOpacity: Double {
        if isPast      { return 0.80 }
        if everReached { return 0.50 }
        return 0.22
    }
}
