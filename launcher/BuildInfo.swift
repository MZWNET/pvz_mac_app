import Foundation

/// `Contents/Resources/build-info.json`, written by scripts/build-engine.sh. Cheat keys (`PVZ_DEBUG`) and bug fixes (`DO_FIX_BUGS`) are compile-time options, so the UI can only reflect what this particular build has. Extra keys in the file are for the build scripts and are ignored here.
struct BuildInfo: Decodable {
    var engineVersionFull = localized("common.unknown")
    var pvzDebug = false
    var doFixBugs = false
    var hasVanilla = false
    var arch = ""

    static let current: BuildInfo = {
        guard let url = Bundle.main.url(forResource: "build-info", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let info = try? JSONDecoder().decode(BuildInfo.self, from: data)
        else { return BuildInfo() }

        return info
    }()
}
