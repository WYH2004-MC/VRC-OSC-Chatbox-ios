import Combine
import Foundation

@MainActor
final class ChatboxViewModel: ObservableObject {
    @Published var host = ""
    @Published var port = "9000"
    @Published var message = ""
    @Published var sendStatus = L10n.text("status.initial")
    @Published var autoConnectOnLaunch = false {
        didSet {
            userDefaults.set(autoConnectOnLaunch, forKey: autoConnectOnLaunchKey)
        }
    }
    @Published var sendTypingIndicatorEnabled = true {
        didSet {
            userDefaults.set(sendTypingIndicatorEnabled, forKey: sendTypingIndicatorEnabledKey)

            if !sendTypingIndicatorEnabled {
                updateTypingIndicator(isMessageFieldFocused: false)
            }
        }
    }
    @Published var livePreviewEnabled = false {
        didSet {
            userDefaults.set(livePreviewEnabled, forKey: livePreviewEnabledKey)

            if !livePreviewEnabled {
                lastPreviewedMessage = nil
            }
        }
    }
    @Published var sendHistoryImmediatelyEnabled = false {
        didSet {
            userDefaults.set(sendHistoryImmediatelyEnabled, forKey: sendHistoryImmediatelyEnabledKey)
        }
    }
    @Published var dictationSendDelay = 1.0 {
        didSet {
            userDefaults.set(Self.clampedDictationSendDelay(dictationSendDelay), forKey: dictationSendDelayKey)
        }
    }
    @Published private(set) var sendHistory: [String] = []
    @Published private(set) var client = OSCChatboxClient()

    private let sendHistoryLimit = 30
    private let sendHistoryKey = "sendHistory"
    private let savedHostKey = "savedHost"
    private let savedPortKey = "savedPort"
    private let autoConnectOnLaunchKey = "autoConnectOnLaunch"
    private let sendTypingIndicatorEnabledKey = "sendTypingIndicatorEnabled"
    private let livePreviewEnabledKey = "livePreviewEnabled"
    private let sendHistoryImmediatelyEnabledKey = "sendHistoryImmediatelyEnabled"
    private let dictationSendDelayKey = "dictationSendDelay"
    private let userDefaults: UserDefaults
    private var isTypingIndicatorActive = false
    private var lastPreviewedMessage: String?
    private var cancellables: Set<AnyCancellable> = []

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        host = userDefaults.string(forKey: savedHostKey) ?? ""
        port = userDefaults.string(forKey: savedPortKey) ?? "9000"
        autoConnectOnLaunch = userDefaults.bool(forKey: autoConnectOnLaunchKey)
        sendTypingIndicatorEnabled = userDefaults.object(forKey: sendTypingIndicatorEnabledKey) as? Bool ?? true
        livePreviewEnabled = userDefaults.bool(forKey: livePreviewEnabledKey)
        sendHistoryImmediatelyEnabled = userDefaults.bool(forKey: sendHistoryImmediatelyEnabledKey)
        dictationSendDelay = Self.clampedDictationSendDelay(
            userDefaults.object(forKey: dictationSendDelayKey) as? Double ?? 1.0
        )
        sendHistory = Array(userDefaults.stringArray(forKey: sendHistoryKey)?.prefix(sendHistoryLimit) ?? [])

        client.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        client.$connectionState
            .dropFirst()
            .sink { [weak self] connectionState in
                self?.syncSendStatus(with: connectionState)
            }
            .store(in: &cancellables)

        if autoConnectOnLaunch, !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            connect()
        }
    }

    var isConnected: Bool {
        client.connectionState.isConnected
    }

    var canSend: Bool {
        isConnected && !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func connect() {
        do {
            let endpoint = try OSCEndpoint(host: host, portText: port)
            host = endpoint.host
            port = String(endpoint.port)
            saveConnectionParameters(endpoint)
            sendStatus = L10n.text("status.connecting")
            isTypingIndicatorActive = false
            lastPreviewedMessage = nil
            client.connect(to: endpoint)
        } catch {
            sendStatus = error.localizedDescription
        }
    }

    func disconnect() {
        updateTypingIndicator(isMessageFieldFocused: false)
        lastPreviewedMessage = nil
        client.disconnect()
        sendStatus = L10n.text("status.disconnected")
    }

    @discardableResult
    func sendMessage() -> Bool {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            sendStatus = L10n.text("error.empty_message")
            return false
        }

        guard isConnected else {
            sendStatus = L10n.text("error.connect_first")
            return false
        }

        client.sendChatboxMessage(trimmedMessage)
        updateTypingIndicator(isMessageFieldFocused: false)
        lastPreviewedMessage = nil
        recordSentMessage(trimmedMessage)
        sendStatus = L10n.text("status.sent")
        message = ""
        return true
    }

    @discardableResult
    func sendTransientMessage(_ message: String, playNotificationSound: Bool = false) -> Bool {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            sendStatus = L10n.text("error.empty_message")
            return false
        }

        guard isConnected else {
            sendStatus = L10n.text("error.connect_first")
            return false
        }

        client.sendChatboxMessage(trimmedMessage, playNotificationSound: playNotificationSound)
        sendStatus = L10n.text("status.sent")
        return true
    }

    func useHistoryItem(_ historyItem: String) {
        message = historyItem
    }

    func handleHistorySelection(_ historyItem: String) -> Bool {
        guard sendHistoryImmediatelyEnabled else {
            useHistoryItem(historyItem)
            return false
        }

        message = historyItem
        return sendMessage()
    }

    func updateTypingIndicator(isMessageFieldFocused: Bool) {
        let shouldShowTyping = isConnected
            && sendTypingIndicatorEnabled
            && isMessageFieldFocused
            && !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        guard shouldShowTyping != isTypingIndicatorActive else {
            return
        }

        client.sendTypingIndicator(shouldShowTyping)
        isTypingIndicatorActive = shouldShowTyping
    }

    func updateLivePreview(isMessageFieldFocused: Bool) {
        let previewMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isConnected, livePreviewEnabled, isMessageFieldFocused else {
            lastPreviewedMessage = nil
            return
        }

        guard previewMessage != lastPreviewedMessage else {
            return
        }

        client.previewChatboxMessage(previewMessage)
        lastPreviewedMessage = previewMessage
    }

    func clearHistory() {
        sendHistory.removeAll()
        saveHistory()
    }

    func recordSentMessage(_ sentMessage: String) {
        sendHistory.removeAll { $0 == sentMessage }
        sendHistory.insert(sentMessage, at: 0)

        if sendHistory.count > sendHistoryLimit {
            sendHistory.removeLast(sendHistory.count - sendHistoryLimit)
        }

        saveHistory()
    }

    private func saveHistory() {
        userDefaults.set(sendHistory, forKey: sendHistoryKey)
    }

    private func syncSendStatus(with connectionState: OSCChatboxClient.ConnectionState) {
        switch connectionState {
        case .connecting:
            sendStatus = L10n.text("status.connecting")
        case .connected:
            if sendStatus == L10n.text("status.connecting") {
                sendStatus = L10n.text("status.connected")
            }
        case .failed(let message):
            sendStatus = message
        case .disconnected:
            if sendStatus == L10n.text("status.connecting") {
                sendStatus = L10n.text("status.disconnected")
            }
        }
    }

    private func saveConnectionParameters(_ endpoint: OSCEndpoint) {
        userDefaults.set(endpoint.host, forKey: savedHostKey)
        userDefaults.set(String(endpoint.port), forKey: savedPortKey)
    }

    private static func clampedDictationSendDelay(_ delay: Double) -> Double {
        min(max(delay, 0.4), 3.0)
    }
}
