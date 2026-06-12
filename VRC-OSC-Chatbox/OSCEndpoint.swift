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
                "请输入 VRChat 所在设备的 IP 地址。"
            case .invalidPort:
                "请输入 1 到 65535 之间的端口号。"
            }
        }
    }
}
