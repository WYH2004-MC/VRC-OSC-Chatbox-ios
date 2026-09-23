//
//  VRC_OSC_ChatboxTests.swift
//  VRC-OSC-ChatboxTests
//
//  Created by WYH2004 on 2026/6/12.
//

import AVFoundation
import Combine
import Foundation
import Network
import Speech
import Testing
import os
@testable import VRC_OSC_Chatbox

struct VRC_OSC_ChatboxTests {

    @Test func chatboxInputEncodesOSCAddressTypeTagsAndString() {
        let data = OSCMessageEncoder.chatboxInput("Hello")
        let expectedBytes: [UInt8] = [
            47, 99, 104, 97, 116, 98, 111, 120, 47, 105, 110, 112, 117, 116, 0, 0,
            44, 115, 84, 84, 0, 0, 0, 0,
            72, 101, 108, 108, 111, 0, 0, 0
        ]

        #expect(Array(data) == expectedBytes)
    }

    @Test func chatboxTypingEncodesOSCBoolTypeTag() {
        let data = OSCMessageEncoder.chatboxTyping(true)
        let expectedBytes: [UInt8] = [
            47, 99, 104, 97, 116, 98, 111, 120, 47, 116, 121, 112, 105, 110, 103, 0,
            44, 84, 0, 0
        ]

        #expect(Array(data) == expectedBytes)
    }

    @Test func chatboxLivePreviewEncodesImmediateDisplayWithoutNotification() {
        let data = OSCMessageEncoder.chatboxInput(
            "Preview",
            sendImmediately: true,
            playNotificationSound: false
        )
        let expectedBytes: [UInt8] = [
            47, 99, 104, 97, 116, 98, 111, 120, 47, 105, 110, 112, 117, 116, 0, 0,
            44, 115, 84, 70, 0, 0, 0, 0,
            80, 114, 101, 118, 105, 101, 119, 0
        ]

        #expect(Array(data) == expectedBytes)
    }

    @Test func emptyChatboxPreviewEncodesEmptyString() {
        let data = OSCMessageEncoder.chatboxInput(
            "",
            sendImmediately: true,
            playNotificationSound: false
        )
        let expectedBytes: [UInt8] = [
            47, 99, 104, 97, 116, 98, 111, 120, 47, 105, 110, 112, 117, 116, 0, 0,
            44, 115, 84, 70, 0, 0, 0, 0,
            0, 0, 0, 0
        ]

        #expect(Array(data) == expectedBytes)
    }

    @Test func endpointTrimsHostAndParsesPort() throws {
        let endpoint = try OSCEndpoint(host: " 192.168.1.20 ", portText: " 9000 ")

        #expect(endpoint.host == "192.168.1.20")
        #expect(endpoint.port == 9000)
    }

    @Test func endpointRejectsInvalidPort() {
        do {
            _ = try OSCEndpoint(host: "192.168.1.20", portText: "70000")
            Issue.record("Expected invalid port to throw.")
        } catch {
            #expect(error as? OSCEndpoint.ValidationError == .invalidPort)
        }
    }

    @MainActor
    @Test func sendHistoryKeepsThirtyRecentUniqueMessages() {
        let userDefaults = UserDefaults(suiteName: "sendHistoryKeepsThirtyRecentUniqueMessages")!
        userDefaults.removePersistentDomain(forName: "sendHistoryKeepsThirtyRecentUniqueMessages")
        let viewModel = ChatboxViewModel(userDefaults: userDefaults)

        for index in 1...31 {
            viewModel.recordSentMessage("Message \(index)")
        }

        viewModel.recordSentMessage("Message 30")

        #expect(viewModel.sendHistory.count == 30)
        #expect(viewModel.sendHistory.first == "Message 30")
        #expect(viewModel.sendHistory.filter { $0 == "Message 30" }.count == 1)
        #expect(!viewModel.sendHistory.contains("Message 1"))
    }

    @MainActor
    @Test func sendHistoryLoadsPersistedMessages() {
        let userDefaults = UserDefaults(suiteName: "sendHistoryLoadsPersistedMessages")!
        userDefaults.removePersistentDomain(forName: "sendHistoryLoadsPersistedMessages")
        userDefaults.set(["Saved message"], forKey: "sendHistory")

        let viewModel = ChatboxViewModel(userDefaults: userDefaults)

        #expect(viewModel.sendHistory == ["Saved message"])
    }

    @MainActor
    @Test func savedConnectionParametersLoadIntoInputFields() {
        let userDefaults = UserDefaults(suiteName: "savedConnectionParametersLoadIntoInputFields")!
        userDefaults.removePersistentDomain(forName: "savedConnectionParametersLoadIntoInputFields")
        userDefaults.set("192.168.1.42", forKey: "savedHost")
        userDefaults.set("9001", forKey: "savedPort")

        let viewModel = ChatboxViewModel(userDefaults: userDefaults)

        #expect(viewModel.host == "192.168.1.42")
        #expect(viewModel.port == "9001")
    }

    @MainActor
    @Test func autoConnectOnLaunchDefaultsToOffAndPersistsChanges() {
        let userDefaults = UserDefaults(suiteName: "autoConnectOnLaunchDefaultsToOffAndPersistsChanges")!
        userDefaults.removePersistentDomain(forName: "autoConnectOnLaunchDefaultsToOffAndPersistsChanges")
        let viewModel = ChatboxViewModel(userDefaults: userDefaults)

        #expect(viewModel.autoConnectOnLaunch == false)

        viewModel.autoConnectOnLaunch = true

        #expect(userDefaults.bool(forKey: "autoConnectOnLaunch") == true)
    }

    @MainActor
    @Test func typingIndicatorSettingDefaultsToOnAndPersistsChanges() {
        let userDefaults = UserDefaults(suiteName: "typingIndicatorSettingDefaultsToOnAndPersistsChanges")!
        userDefaults.removePersistentDomain(forName: "typingIndicatorSettingDefaultsToOnAndPersistsChanges")
        let viewModel = ChatboxViewModel(userDefaults: userDefaults)

        #expect(viewModel.sendTypingIndicatorEnabled == true)

        viewModel.sendTypingIndicatorEnabled = false

        #expect(userDefaults.object(forKey: "sendTypingIndicatorEnabled") as? Bool == false)
    }

    @MainActor
    @Test func livePreviewSettingDefaultsToOffAndPersistsChanges() {
        let userDefaults = UserDefaults(suiteName: "livePreviewSettingDefaultsToOffAndPersistsChanges")!
        userDefaults.removePersistentDomain(forName: "livePreviewSettingDefaultsToOffAndPersistsChanges")
        let viewModel = ChatboxViewModel(userDefaults: userDefaults)

        #expect(viewModel.livePreviewEnabled == false)

        viewModel.livePreviewEnabled = true

        #expect(userDefaults.bool(forKey: "livePreviewEnabled") == true)
    }

    @MainActor
    @Test func sendHistoryImmediatelySettingDefaultsToOffAndPersistsChanges() {
        let userDefaults = UserDefaults(suiteName: "sendHistoryImmediatelySettingDefaultsToOffAndPersistsChanges")!
        userDefaults.removePersistentDomain(forName: "sendHistoryImmediatelySettingDefaultsToOffAndPersistsChanges")
        let viewModel = ChatboxViewModel(userDefaults: userDefaults)

        #expect(viewModel.sendHistoryImmediatelyEnabled == false)

        viewModel.sendHistoryImmediatelyEnabled = true

        #expect(userDefaults.bool(forKey: "sendHistoryImmediatelyEnabled") == true)
    }

    @Test func audioActivityIgnoresSilenceAndAcceptsSpeechOffTheMainThread() async throws {
        let monitor = AudioActivityMonitor()
        let initialActivity = monitor.lastActivityAt
        try await Task.detached {
            let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
            let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024))
            let samples = try #require(buffer.floatChannelData?[0])
            let tap = monitor.makeTap(for: SFSpeechAudioBufferRecognitionRequest())
            let time = AVAudioTime(sampleTime: 0, atRate: 48_000)

            monitor.record(buffer)
            #expect(monitor.lastActivityAt == initialActivity)

            buffer.frameLength = 1024
            samples.update(repeating: 0.01, count: 1024)
            tap(buffer, time)
            #expect(monitor.lastActivityAt == initialActivity)

            samples.update(repeating: 0.02, count: 1024)
            tap(buffer, time)
            let speechActivity = monitor.lastActivityAt
            #expect(speechActivity > initialActivity)

            samples.update(repeating: 0, count: 1024)
            tap(buffer, time)
            #expect(monitor.lastActivityAt == speechActivity)
        }.value
    }

    @MainActor
    @Test(.timeLimit(.minutes(1)))
    func sendsOSCWithoutRepublishingConnectionAndDisconnectsCleanly() async throws {
        let receiver = try LocalOSCReceiver()
        defer { receiver.stop() }
        let port = try await receiver.start()
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let viewModel = ChatboxViewModel(userDefaults: defaults)
        defer { viewModel.disconnect() }
        viewModel.host = "127.0.0.1"
        viewModel.port = String(port)
        viewModel.connect()
        for await state in viewModel.client.$connectionState.values {
            if case .failed(let error) = state {
                Issue.record("Connection failed: \(error)")
                return
            }
            if state.isConnected { break }
        }

        var connectionUpdates = 0
        let subscription = viewModel.client.$connectionState.dropFirst().sink { _ in
            connectionUpdates += 1
        }
        defer { subscription.cancel() }
        var packets = receiver.packets.makeAsyncIterator()
        viewModel.message = "  Hello  "
        #expect(viewModel.sendMessage())
        #expect(await packets.next() == OSCMessageEncoder.chatboxInput("Hello"))
        #expect(viewModel.message.isEmpty)
        #expect(viewModel.sendHistory == ["Hello"])

        #expect(viewModel.sendTransientMessage("Dictation"))
        #expect(await packets.next() == OSCMessageEncoder.chatboxInput("Dictation", playNotificationSound: false))
        #expect(viewModel.sendHistory == ["Hello"])
        #expect(connectionUpdates == 0)

        viewModel.message = "Typing"
        viewModel.updateTypingIndicator(isMessageFieldFocused: true)
        #expect(await packets.next() == OSCMessageEncoder.chatboxTyping(true))
        viewModel.disconnect()
        #expect(await packets.next() == OSCMessageEncoder.chatboxTyping(false))
        // Let already queued completion/state callbacks run after cancellation.
        try await Task.sleep(for: .milliseconds(100))
        #expect(viewModel.client.connectionState == .disconnected)
        #expect(connectionUpdates == 1)
    }
}

private final class LocalOSCReceiver {
    let packets: AsyncStream<Data>
    private let packetContinuation: AsyncStream<Data>.Continuation
    private let listener: NWListener
    private let connections = OSAllocatedUnfairLock(initialState: [NWConnection]())

    init() throws {
        (packets, packetContinuation) = AsyncStream.makeStream()
        listener = try NWListener(using: .udp)
    }

    func start() async throws -> UInt16 {
        let (ports, continuation) = AsyncThrowingStream<UInt16, Error>.makeStream()
        listener.stateUpdateHandler = { [weak listener] state in
            switch state {
            case .ready:
                if let port = listener?.port {
                    continuation.yield(port.rawValue)
                    continuation.finish()
                }
            case .failed(let error):
                continuation.finish(throwing: error)
            default:
                break
            }
        }
        listener.newConnectionHandler = { [connections, packetContinuation] connection in
            connections.withLock { $0.append(connection) }
            connection.start(queue: .global())
            Self.receive(on: connection, into: packetContinuation)
        }
        listener.start(queue: .global())
        var iterator = ports.makeAsyncIterator()
        return try #require(await iterator.next())
    }

    func stop() {
        listener.cancel()
        connections.withLock { $0.forEach { $0.cancel() } }
        packetContinuation.finish()
    }

    private static func receive(on connection: NWConnection, into continuation: AsyncStream<Data>.Continuation) {
        connection.receiveMessage { data, _, _, error in
            if let data { continuation.yield(data) }
            if error == nil {
                receive(on: connection, into: continuation)
            }
        }
    }
}
