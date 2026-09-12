import AppKit

/// A hand-rolled AppKit app has no menu bar, and without one there is no ⌘Q — nor ⌘C/⌘V/⌘A in text fields, which are dispatched through menu item key equivalents.
enum MainMenu {
    static func install() {
        let app = [
            [item(localized("menu.about"), #selector(NSApplication.orderFrontStandardAboutPanel(_:)))],
            [item(localized("menu.hide"), #selector(NSApplication.hide(_:)), "h")],
            [item(localized("menu.quit"), #selector(NSApplication.terminate(_:)), "q")],
        ]
        let edit = [
            [
                item(localized("menu.undo"), Selector(("undo:")), "z"),
                item(localized("menu.redo"), Selector(("redo:")), "Z"),
            ],
            [
                item(localized("menu.cut"), #selector(NSText.cut(_:)), "x"),
                item(localized("menu.copy"), #selector(NSText.copy(_:)), "c"),
                item(localized("menu.paste"), #selector(NSText.paste(_:)), "v"),
                item(localized("menu.select_all"), #selector(NSText.selectAll(_:)), "a"),
            ],
        ]

        let bar = NSMenu()
        bar.addItem(menu(title: "", groups: app))
        bar.addItem(menu(title: localized("menu.edit"), groups: edit))
        NSApp.mainMenu = bar
    }

    private static func menu(title: String, groups: [[NSMenuItem]]) -> NSMenuItem {
        let submenu = NSMenu(title: title)
        for (index, group) in groups.enumerated() {
            if index > 0 { submenu.addItem(.separator()) }
            for entry in group { submenu.addItem(entry) }
        }

        let entry = NSMenuItem()
        entry.submenu = submenu

        return entry
    }

    private static func item(_ title: String, _ action: Selector, _ key: String = "") -> NSMenuItem {
        NSMenuItem(title: title, action: action, keyEquivalent: key)
    }
}
