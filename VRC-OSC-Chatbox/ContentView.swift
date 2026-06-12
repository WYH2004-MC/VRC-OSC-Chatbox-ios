//
//  ContentView.swift
//  VRC-OSC-Chatbox
//
//  Created by WYH2004 on 2026/6/12.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ChatboxViewModel()
    @State private var selectedTab: AppTab = .chatbox
    @State private var toastMessage: String?
    @FocusState private var focusedField: Field?

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                chatboxForm
                    .navigationTitle("VRC OSC Chatbox")
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("完成") {
                                focusedField = nil
                            }
                        }
                    }
            }
            .tabItem {
                Label("发送", systemImage: "paperplane.fill")
            }
            .tag(AppTab.chatbox)

            NavigationStack {
                historyList
                    .navigationTitle("发送历史")
            }
            .tabItem {
                Label("历史", systemImage: "clock.arrow.circlepath")
            }
            .tag(AppTab.history)

            NavigationStack {
                settingsView
                    .navigationTitle("设置")
            }
            .tabItem {
                Label("设置", systemImage: "gearshape")
            }
            .tag(AppTab.settings)

            NavigationStack {
                aboutView
                    .navigationTitle("关于")
            }
            .tabItem {
                Label("关于", systemImage: "info.circle")
            }
            .tag(AppTab.about)
        }
        .onChange(of: focusedField) { _, newValue in
            viewModel.updateTypingIndicator(isMessageFieldFocused: newValue == .message)
            viewModel.updateLivePreview(isMessageFieldFocused: newValue == .message)
        }
        .onChange(of: viewModel.message) { _, _ in
            viewModel.updateTypingIndicator(isMessageFieldFocused: focusedField == .message)
            viewModel.updateLivePreview(isMessageFieldFocused: focusedField == .message)
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue != .chatbox {
                focusedField = nil
                viewModel.updateTypingIndicator(isMessageFieldFocused: false)
                viewModel.updateLivePreview(isMessageFieldFocused: false)
            }
        }
        .overlay(alignment: .top) {
            if let toastMessage {
                Text(toastMessage)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.82), in: Capsule())
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toastMessage)
    }

    private var chatboxForm: some View {
        Form {
            Section("VRChat OSC") {
                TextField("IP 地址，例如 192.168.1.20", text: $viewModel.host)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
                    .focused($focusedField, equals: .host)

                TextField("端口", text: $viewModel.port)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .port)

                HStack {
                    Label(viewModel.client.connectionState.statusText, systemImage: statusIconName)
                        .foregroundStyle(statusColor)

                    Spacer()

                    if viewModel.isConnected {
                        Button("断开") {
                            viewModel.disconnect()
                        }
                    } else {
                        Button {
                            focusedField = nil
                            viewModel.connect()
                        } label: {
                            Text("连接")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            Section("发送文字") {
                TextField("输入要显示到 VRChat Chatbox 的文字", text: $viewModel.message, axis: .vertical)
                    .lineLimit(3...6)
                    .focused($focusedField, equals: .message)

                Button {
                    focusedField = nil
                    if viewModel.sendMessage() {
                        showToast("已发送")
                    }
                } label: {
                    Label("发送到 VRChat", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canSend)
            }

            Section {
                Text(viewModel.sendStatus)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var historyList: some View {
        Form {
            if viewModel.sendHistory.isEmpty {
                ContentUnavailableView(
                    "暂无发送历史",
                    systemImage: "clock",
                    description: Text("保留最近30条的发送记录")
                )
            } else {
                Section {
                    ForEach(viewModel.sendHistory, id: \.self) { historyItem in
                        Button {
                            guard !viewModel.sendHistoryImmediatelyEnabled || viewModel.isConnected else {
                                showToast("请先连接 VRChat OSC")
                                return
                            }

                            let didSendMessage = viewModel.handleHistorySelection(historyItem)
                            if didSendMessage {
                                showToast("已发送")
                            } else {
                                selectedTab = .chatbox
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "text.bubble")
                                    .foregroundStyle(.secondary)

                                Text(historyItem)
                                    .lineLimit(2)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Image(systemName: viewModel.sendHistoryImmediatelyEnabled ? "paperplane" : "arrow.uturn.left")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    Button(role: .destructive) {
                        viewModel.clearHistory()
                    } label: {
                        Label("清空历史", systemImage: "trash")
                    }
                } footer: {
                    Text(historyFooterText)
                }
            }
        }
    }

    private var settingsView: some View {
        Form {
            Section {
                Toggle("启动时自动连接 OSC", isOn: $viewModel.autoConnectOnLaunch)
            } footer: {
                Text("开启后，下次启动会使用上次成功连接时保存的 IP 和端口自动连接。")
            }

            Section {
                Toggle("输入时显示正在输入", isOn: $viewModel.sendTypingIndicatorEnabled)
            } footer: {
                Text("开启后，在消息输入框中输入文字时会在 VRChat 显示正在输入提示。")
            }

            Section {
                Toggle("实时预览输入文字", isOn: $viewModel.livePreviewEnabled)
            } footer: {
                Text("开启后，在消息输入框中键入文字时会实时显示到 VRChat。")
            }

            Section {
                Toggle("点击历史直接发送消息", isOn: $viewModel.sendHistoryImmediatelyEnabled)
            } footer: {
                Text("开启后，在发送历史中点选消息会直接发送")
            }
        }
    }

    private var historyFooterText: String {
        if viewModel.sendHistoryImmediatelyEnabled {
            "点选历史记录会直接发送消息。"
        } else {
            "点选历史记录会切回发送界面，并填入输入框。"
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }

    private var aboutView: some View {
        Form {
            Section {
                VStack(alignment: .center, spacing: 12) {
                    Image(systemName: "message.badge.waveform.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.tint)

                    Text("VRC OSC Chatbox")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("通过 VRChat OSC 接口发送 Chatbox 文字消息。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            Section("版本") {
                LabeledContent("当前版本", value: appVersionText)
                LabeledContent("Bundle ID", value: bundleIdentifier)
            }

            Section("作者") {
                Link(destination: githubProfileURL) {
                    HStack(spacing: 16) {
                        AsyncImage(url: githubAvatarURL) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text("WYH2004-MC")
                                .foregroundStyle(.primary)

                            Text(githubProfileURL.absoluteString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.forward")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private var githubProfileURL: URL {
        URL(string: "https://github.com/WYH2004-MC")!
    }

    private var githubAvatarURL: URL {
        URL(string: "https://github.com/WYH2004-MC.png")!
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        return "\(version) (\(build))"
    }

    private var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "Unknown"
    }

    private enum AppTab: Equatable {
        case chatbox
        case history
        case settings
        case about
    }

    private var statusIconName: String {
        switch viewModel.client.connectionState {
        case .connected:
            "checkmark.circle.fill"
        case .connecting:
            "clock.fill"
        case .failed:
            "exclamationmark.triangle.fill"
        case .disconnected:
            "circle"
        }
    }

    private var statusColor: Color {
        switch viewModel.client.connectionState {
        case .connected:
            .green
        case .connecting:
            .orange
        case .failed:
            .red
        case .disconnected:
            .secondary
        }
    }

    private enum Field: Equatable {
        case host
        case port
        case message
    }
}

#Preview {
    ContentView()
}
