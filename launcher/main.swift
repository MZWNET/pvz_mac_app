import AppKit
import CoreGraphics

// Launcher for PvZ-Portable. It exists because the engine needs -resdir to find assets kept outside the bundle, because -cheat can't be passed by double-clicking an icon, and because LaunchServices' injected arguments would otherwise make the engine exit.

let store = OptionsStore()

// CGEventSource rather than NSEvent.modifierFlags: it needs no NSApplication, so the common "assets ready, screen skipped" path never touches AppKit and execs straight through.
let optionKeyHeld = CGEventSource.flagsState(.combinedSessionState).contains(.maskAlternate)

var startupError: Error?
if store.options.skipHome, !optionKeyHeld, store.options.resourcesReady {
    do {
        try EngineLauncher.exec(store.options)
    } catch {
        startupError = error
    }
}

let app = NSApplication.shared
let delegate = AppDelegate(store: store, startupError: startupError)
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
