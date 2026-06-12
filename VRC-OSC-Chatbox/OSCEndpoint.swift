import Foundation

struct OSCEndpoint: Equatable {
    let host: String
    let port: UInt16

    init(host: String, portText: String) throws {
        let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPort = portText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedHost.isEmpty else {
            throw ValidationError.emptyHost
        }

        guard let portValue = UInt16(normalizedPort), portValue > 0 else {
            throw ValidationError.invalidPort
        }

        self.host = normalizedHost
        self.port = portValue
    }
}

extension OSCEndpoint {
    enum ValidationError: LocalizedError, Equatable {
        case emptyHost
        case invalidPort

        var errorDescription: String? {
            switch self {
            case .emptyHost:
                L10n.text("error.empty_host")
            case .invalidPort:
                L10n.text("error.invalid_port")
            }
        }
    }
}
