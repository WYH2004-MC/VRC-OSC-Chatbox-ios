//
//  VRC_OSC_ChatboxTests.swift
//  VRC-OSC-ChatboxTests
//
//  Created by WYH2004 on 2026/6/12.
//

import Foundation
import Testing
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

}
