// ContentView.swift
// The root router: decides whether the player sees the title screen,
// character select, or the game itself.

import SwiftUI

// MARK: - Root (router)

struct ContentView: View {
    @State private var selectedCharacter: CharacterClass? = {
        if let id = DungeonGame.savedCharacterID() {
            return CharacterClass.all.first(where: { $0.id == id })
        }
        return nil
    }()
    @State private var previousCharacter: CharacterClass? = nil
    @State private var showTitle = true
    // Set only when "Change Hero" is tapped mid-run (never for the title
    // screen's "New Hero"). Lets onSelect below tell the two flows apart:
    // a mid-run swap must preserve soul shards, prestige upgrades, deepest
    // floor ever, etc. via DungeonGame.changeCharacter(to:); a deliberate
    // "New Hero" from the title screen is the one place a full wipe is correct.
    @State private var pendingHeroSwap: DungeonGame? = nil

    var body: some View {
        if showTitle {
            TitleScreenView(
                hasSave: selectedCharacter != nil,
                onContinue: {
                    withAnimation(.easeInOut(duration: 0.35)) { showTitle = false }
                },
                onNewHero: {
                    // Remember the saved hero (if any) so the player can cancel
                    // back to it; the save is only cleared once a new hero is
                    // actually chosen (handled in onSelect below).
                    previousCharacter = selectedCharacter
                    selectedCharacter = nil
                    withAnimation(.easeInOut(duration: 0.35)) { showTitle = false }
                }
            )
            .transition(.opacity)
        } else if let character = selectedCharacter {
            GameView(character: character) { liveGame in
                liveGame.save()
                pendingHeroSwap  = liveGame
                previousCharacter = character
                selectedCharacter = nil
            }
        } else {
            CharacterSelectView(
                onCancel: previousCharacter != nil ? {
                    selectedCharacter = previousCharacter
                    previousCharacter = nil
                    pendingHeroSwap   = nil
                } : nil,
                onSelect: { newCharacter in
                    if let liveGame = pendingHeroSwap {
                        liveGame.changeCharacter(to: newCharacter)
                        liveGame.save()
                    } else if previousCharacter != nil {
                        DungeonGame.clearSave()
                    }
                    pendingHeroSwap   = nil
                    selectedCharacter = newCharacter
                    previousCharacter = nil
                    Analytics.characterSelected(characterID: newCharacter.id)
                },
                isDestructiveReset: pendingHeroSwap == nil
            )
        }
    }
}
