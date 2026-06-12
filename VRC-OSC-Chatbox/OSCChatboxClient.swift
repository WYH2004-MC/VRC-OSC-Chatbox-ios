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

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.handle(state)
            }
        }

        self.connection = connection
        connection.start(queue: .global(qos: .userInitiated))
    }

    func disconnect() {
        if connectionState.isConnected {
            sendTypingIndicator(false)
        }

        connection?.cancel()
        connection = nil
        endpointDescription = ""
        connectionState = .disconnected
    }

    func sendChatboxMessage(_ message: String) {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            connectionState = .failed(L10n.text("error.empty_message"))
            return
        }

        guard connectionState.isConnected else {
            connectionState = .failed(L10n.text("error.connect_first"))
            return
        }

        let payload = OSCMessageEncoder.chatboxInput(trimmedMessage)
        send(payload)
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

    private func send(_ payload: Data) {
        guard let connection, connectionState.isConnected else {
            connectionState = .failed(L10n.text("error.connect_first"))
            return
        }

        connection.send(content: payload, completion: .contentProcessed { [weak self] error in
            Task { @MainActor in
                guard let self else {
                    return
                }

                if let error {
                    self.connectionState = .failed(L10n.text("error.send_failed", error.localizedDescription))
                } else {
                    self.connectionState = .connected(self.endpointDescription)
                }
            }
        })
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
