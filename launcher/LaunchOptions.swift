import Foundation

/// The engine's demo flags are mutually exclusive in its own parser, so they are one choice here rather than four booleans.
enum DemoMode: String, Codable {
    case off, record, recnum, play, playnum
}

/// Every runtime argument the engine accepts. It shows a dialog and exits on anything it can't parse, so the assembled argv has to stay clean.
struct LaunchOptions: Codable {
    var resourceDir = Paths.appSupport.path
    var saveDir = ""
    var useVanillaEngine = false

    var cheat = false
    var screensaver = false
    var crash = false

    var demoMode = DemoMode.off
    var recordPath = ""
    var recordKeep = 1
    var playPath = ""
    var playIndex = 1

    var extraArguments = ""
    var skipHome = false

    var resourceDirURL: URL { URL(fileURLWithPath: resourceDir) }

    var engineURL: URL { Paths.engine(vanilla: useVanillaEngine) }

    var resourcesReady: Bool { Paths.hasGameResources(at: resourceDirURL) }

    /// Always `-flag=value`: without the `=` the parser swallows the next argv entry, and the `=` form needs no quoting for paths with spaces.
    var arguments: [String] {
        var args = ["-resdir=\(resourceDir)"]

        if !saveDir.isEmpty { args.append("-savedir=\(saveDir)") }
        if cheat { args.append("-cheat") }
        if screensaver { args.append("-screensaver") }

        switch demoMode {
        case .off: break
        case .record: args.append(recordPath.isEmpty ? "-record" : "-record=\(recordPath)")
        case .recnum: args.append("-recnum=\(recordKeep)")
        case .play: args.append(playPath.isEmpty ? "-play" : "-play=\(playPath)")
        case .playnum: args.append("-playnum=\(playIndex)")
        }

        if crash { args.append("-crash") }
        args.append(contentsOf: Self.tokenize(extraArguments))

        return args
    }

    var commandLinePreview: String {
        ([engineURL.lastPathComponent] + arguments)
            .map { $0.contains(" ") ? "\"\($0)\"" : $0 }
            .joined(separator: " ")
    }

    /// Shell-style splitting for the free-form field; single and double quotes group.
    private static func tokenize(_ input: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var quote: Character?
        var started = false

        for ch in input {
            if let open = quote {
                if ch == open { quote = nil } else { current.append(ch) }
            } else if ch == "\"" || ch == "'" {
                quote = ch
                started = true
            } else if ch.isWhitespace {
                if started || !current.isEmpty {
                    tokens.append(current)
                    current = ""
                    started = false
                }
            } else {
                current.append(ch)
            }
        }
        if started || !current.isEmpty { tokens.append(current) }

        return tokens
    }
}

/// Observable holder that persists itself to UserDefaults as one JSON blob on every change.
final class OptionsStore: ObservableObject {
    private static let key = "LaunchOptions"

    @Published var options: LaunchOptions {
        didSet { save() }
    }

    init() {
        let stored = UserDefaults.standard.data(forKey: Self.key)
        options = stored.flatMap { try? JSONDecoder().decode(LaunchOptions.self, from: $0) } ?? LaunchOptions()
    }

    private func save() {
        UserDefaults.standard.set(try! JSONEncoder().encode(options), forKey: Self.key)
    }
}
