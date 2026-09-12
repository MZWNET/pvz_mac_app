import Foundation

/// Keys are semantic (`home.start`), not English prose: several strings are multi-line and take arguments, where one stray character would silently fall back to showing the raw key. scripts/verify-app.sh diffs the key sets of the .strings files.
func localized(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

/// Arguments use `%@` / `%d` placeholders so interpolation can't alter the key itself.
func localized(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), arguments: arguments)
}
