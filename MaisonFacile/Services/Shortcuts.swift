import AppIntents

/// Phrases Siri disponibles sans aucun réglage (app uniquement, pas le widget).
/// Ex. « Dis Siri, Soirée avec Maison Facile », « Dis Siri, mets Couleur 3 avec Maison Facile ».
struct MaisonShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: RunSceneIntent(),
                    phrases: ["\(\.$scene) avec \(.applicationName)",
                              "Lance \(\.$scene) avec \(.applicationName)"],
                    shortTitle: "Bouton maison",
                    systemImageName: "house.fill")
        AppShortcut(intent: PlayRadioIntent(),
                    phrases: ["Mets \(\.$station) avec \(.applicationName)",
                              "Écoute \(\.$station) avec \(.applicationName)"],
                    shortTitle: "Radio",
                    systemImageName: "radio.fill")
        AppShortcut(intent: PauseIntent(),
                    phrases: ["Pause avec \(.applicationName)",
                              "Coupe la musique avec \(.applicationName)"],
                    shortTitle: "Pause",
                    systemImageName: "pause.fill")
    }
}
