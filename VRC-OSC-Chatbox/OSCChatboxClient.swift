import Combine
import Foundation
import Network

@MainActor
final class OSCChatboxClient: ObservableObject {
    enum ConnectionState: Equatable {
        case disconnected
        case connecting(String)
        case connected(String)
        case failed(String)

        var isConnected: Bool {
            if case .connected = self {
                true
            } else {
                false
            }
        }

        var statusText: String {
            switch self {
            case .disconnected:
                L10n.text("connection.disconnected")
            case .connecting(let endpoint):
                L10n.text("connection.connecting", endpoint)
            case .connected(let endpoint):
                L10n.text("connection.connected", endpoint)
            case .failed(let message):
                message
            }
        }
    }

    @Published private(set) var connectionState: ConnectionState = .disconnected

    private var connection: NWConnection?
    private var endpointDescription = ""

    func connect(to endpoint: OSCEndpoint) {
        disconnect()

        endpointDescription = "\(endpoint.host):\(endpoint.port)"
        connectionState = .connecting(endpointDescription)

        let connection = NWConnection(
            host: NWEndpoint.Host(endpoint.host),
            port: NWEndpoint.Port(rawValue: endpoint.port)!,
            using: .udp
        )

        connection.stateUpdateHandler = { [weak self, weak connection] state in
            Task { @MainActor [weak self, weak connection] in
                guard let self, let connection, self.connection === connection else {
                    return
                }

                self.handle(state)
            }
        }

        self.connection = connection
        connection.start(queue: .global(qos: .userInitiated))
    }

    func disconnect() {
        if let connection {
            connection.stateUpdateHandler = nil
            if connectionState.isConnected {
                // Let the final typing update leave the send queue before cancelling it.
                connection.send(
                    content: OSCMessageEncoder.chatboxTyping(false),
                    completion: .contentProcessed { _ in connection.cancel() }
                )
            } else {
                connection.cancel()
            }
        }

        connection = nil
        endpointDescription = ""
        if connectionState != .disconnected {
            connectionState = .disconnected
        }
    }

    func sendChatboxMessage(_ message: String, playNotificationSound: Bool = true) {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            connectionState = .failed(L10n.text("error.empty_message"))
            return
        }

        guard let connection, connectionState.isConnected else {
            connectionState = .failed(L10n.text("error.connect_first"))
            return
        }

        let payload = OSCMessageEncoder.chatboxInput(
            trimmedMessage,
            playNotificationSound: playNotificationSound
        )
        connection.send(content: payload, completion: .contentProcessed { [weak self, weak connection] error in
            guard let error else {
                return
            }

            Task { @MainActor [weak self, weak connection] in
                guard let self, let connection, self.connection === connection else {
                    return
                }

                self.connectionState = .failed(L10n.text("error.send_failed", error.localizedDescription))
            }
        })
    }

    func previewChatboxMessage(_ message: String) {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let connection, connectionState.isConnected else {
            return
        }

        let payload = OSCMessageEncoder.chatboxInput(
            trimmedMessage,
            sendImmediately: true,
            playNotificationSound: false
        )
        connection.send(content: payload, completion: .contentProcessed { _ in })
    }

    func sendTypingIndicator(_ isTyping: Bool) {
        guard let connection, connectionState.isConnected else {
            return
        }

        let payload = OSCMessageEncoder.chatboxTyping(isTyping)
        connection.send(content: payload, completion: .contentProcessed { _ in })
    }

    private func handle(_ state: NWConnection.State) {
        switch state {
        case .ready:
            connectionState = .connected(endpointDescription)
        case .failed(let error):
            connectionState = .failed(L10n.text("error.connection_failed", error.localizedDescription))
            connection?.cancel()
            connection = nil
        case .cancelled:
            connectionState = .disconnected
        default:
            break
        }
    }
}
