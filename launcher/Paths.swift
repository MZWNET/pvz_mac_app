import AppKit

enum Paths {
    /// The engine hardcodes `SDL_GetPrefPath("io.github.wszqkzqk", "PvZPortable")` for saves, independent of the bundle id. Assets default here too, which keeps the .app replaceable wholesale and free of copyrighted material.
    static let appSupport = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/io.github.wszqkzqk/PvZPortable", isDirectory: true)

    /// Next to the launcher in Contents/MacOS, so `@executable_path/libs/` still resolves after the exec.
    static func engine(vanilla: Bool) -> URL {
        Bundle.main.bundleURL
            .appendingPathComponent("Contents/MacOS", isDirectory: true)
            .appendingPathComponent(vanilla ? "pvz-portable-vanilla" : "pvz-portable")
    }

    /// Upstream's own test for "this directory holds game assets".
    static func hasGameResources(at dir: URL) -> Bool {
        isFile(dir.appendingPathComponent("main.pak"))
            && isDirectory(dir.appendingPathComponent("properties"))
    }

    static func isFile(_ url: URL) -> Bool { exists(url, directory: false) }

    static func isDirectory(_ url: URL) -> Bool { exists(url, directory: true) }

    static func revealInFinder(_ url: URL) {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private static func exists(_ url: URL, directory: Bool) -> Bool {
        var isDir: ObjCBool = false
        let found = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)

        return found && isDir.boolValue == directory
    }
}
