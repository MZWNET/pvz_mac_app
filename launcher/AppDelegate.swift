import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store: OptionsStore
    private let startupError: Error?
    private var window: NSWindow?

    init(store: OptionsStore, startupError: Error?) {
        self.store = store
        self.startupError = startupError
    }

    func applicationDidFinishLaunching(_: Notification) {
        MainMenu.install()

        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "PvZ Portable"
        window.contentView = NSHostingView(
            rootView: HomeView(store: store, startupError: startupError)
        )
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool { true }

    func applicationSupportsSecureRestorableState(_: NSApplication) -> Bool { true }
}
