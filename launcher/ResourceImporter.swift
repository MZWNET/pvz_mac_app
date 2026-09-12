import AppKit
import UniformTypeIdentifiers

/// Imports a user-supplied copy of the GOTY assets. The desktop engine has no importer of its own — without assets it just prints "place main.pak and the properties/ folder into …" and exits.
enum ResourceImporter {
    enum Failure: LocalizedError {
        case notFound(URL)
        case unzipFailed(Int32)

        var errorDescription: String? {
            switch self {
            case .notFound(let url):
                return localized("error.import.not_found", url.lastPathComponent)
            case .unzipFailed(let code):
                return localized("error.import.unzip_failed", code)
            }
        }
    }

    /// Top-level entries an unpacked pak produces. Copying only these keeps PlantsVsZombies.exe and friends out.
    private static let knownEntries = [
        "main.pak", "properties",
        "images", "sounds", "data", "fonts", "particles", "reanim", "compiled",
    ]

    @MainActor
    static func chooseSource() -> URL? {
        let panel = NSOpenPanel()
        panel.title = localized("import.panel.title")
        panel.message = localized("import.panel.message")
        panel.prompt = localized("import.panel.prompt")
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.zip]

        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Copies assets out of `source` (a directory or a zip) into `destination`, overwriting entries of the same name.
    static func importResources(from source: URL, into destination: URL) throws {
        let fm = FileManager.default
        var scratch: URL?
        defer { scratch.map { try? fm.removeItem(at: $0) } }

        let searchRoot: URL
        if source.pathExtension.lowercased() == "zip" {
            let temp = fm.temporaryDirectory
                .appendingPathComponent("pvzp-import-\(UUID().uuidString)", isDirectory: true)
            scratch = temp
            try fm.createDirectory(at: temp, withIntermediateDirectories: true)
            try unzip(source, into: temp)
            searchRoot = temp
        } else {
            searchRoot = source
        }

        guard let root = locateResourceRoot(in: searchRoot) else {
            throw Failure.notFound(source)
        }

        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        for name in knownEntries {
            let from = root.appendingPathComponent(name)
            guard fm.fileExists(atPath: from.path) else { continue }

            let to = destination.appendingPathComponent(name)
            if fm.fileExists(atPath: to.path) {
                try fm.removeItem(at: to)
            }
            try fm.copyItem(at: from, to: to)
        }
    }

    private static func unzip(_ zip: URL, into directory: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", zip.path, directory.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw Failure.unzipFailed(process.terminationStatus)
        }
    }

    /// Assets sit either directly in the chosen directory or one wrapper level down, which is what zips usually look like.
    private static func locateResourceRoot(in directory: URL) -> URL? {
        if looksLikeResourceRoot(directory) { return directory }

        let children = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        return children?.first { Paths.isDirectory($0) && looksLikeResourceRoot($0) }
    }

    /// Looser than `Paths.hasGameResources`: the engine also accepts extracted assets in place of main.pak.
    private static func looksLikeResourceRoot(_ directory: URL) -> Bool {
        guard Paths.isDirectory(directory.appendingPathComponent("properties")) else { return false }
        if Paths.isFile(directory.appendingPathComponent("main.pak")) { return true }

        return ["images", "sounds", "data", "reanim"].contains {
            Paths.isDirectory(directory.appendingPathComponent($0))
        }
    }
}
