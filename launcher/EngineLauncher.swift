import Darwin
import Foundation

enum EngineLauncher {
    enum Failure: LocalizedError {
        case engineMissing(URL)
        case execFailed(String, Int32)

        var errorDescription: String? {
            switch self {
            case .engineMissing(let url):
                return localized("error.engine_missing", url.lastPathComponent)
            case .execFailed(let path, let code):
                return localized("error.exec_failed", path, String(cString: strerror(code)))
            }
        }
    }

    /// Replaces this process with the engine instead of spawning it: the PID doesn't change, so LaunchServices still sees one app and the Dock icon doesn't bounce twice. The main executable stays in Contents/MacOS, keeping `@executable_path/libs/` and `NSBundle.mainBundle` valid.
    ///
    /// Only the argv assembled here is passed on. LaunchServices sometimes injects `-psn_0_xxxxx`, and the engine exits on any argument it doesn't recognise.
    static func exec(_ options: LaunchOptions) throws -> Never {
        let engine = options.engineURL
        guard FileManager.default.isExecutableFile(atPath: engine.path) else {
            throw Failure.engineMissing(engine)
        }

        var argv: [UnsafeMutablePointer<CChar>?] = ([engine.path] + options.arguments).map { strdup($0) }
        argv.append(nil)
        defer { for pointer in argv { free(pointer) } }

        execv(engine.path, &argv)

        throw Failure.execFailed(engine.path, errno)
    }
}
