import Foundation

enum L10n {
    static func text(_ key: String.LocalizationValue) -> String {
        String(localized: key)
    }

    static func text(_ key: String.LocalizationValue, _ arguments: CVarArg...) -> String {
        String(format: String(localized: key), arguments: arguments)
    }
}
