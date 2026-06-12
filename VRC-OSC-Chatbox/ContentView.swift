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
                            Button("done") {
                                focusedField = nil
                            }
                        }
                    }
            }
            .tabItem {
                Label("tab.send", systemImage: "paperplane.fill")
            }
            .tag(AppTab.chatbox)

            NavigationStack {
                historyList
                    .navigationTitle("history.title")
            }
            .tabItem {
                Label("tab.history", systemImage: "clock.arrow.circlepath")
            }
            .tag(AppTab.history)

            NavigationStack {
                settingsView
                    .navigationTitle("settings.title")
            }
            .tabItem {
                Label("tab.settings", systemImage: "gearshape")
            }
            .tag(AppTab.settings)

            NavigationStack {
                aboutView
                    .navigationTitle("about.title")
            }
            .tabItem {
                Label("tab.about", systemImage: "info.circle")
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
            Section("section.vrchat_osc") {
                TextField("field.host.placeholder", text: $viewModel.host)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
                    .focused($focusedField, equals: .host)

                TextField("field.port.placeholder", text: $viewModel.port)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .port)

                HStack {
                    Label(viewModel.client.connectionState.statusText, systemImage: statusIconName)
                        .foregroundStyle(statusColor)

                    Spacer()

                    if viewModel.isConnected {
                        Button("disconnect") {
                            viewModel.disconnect()
                        }
                    } else {
                        Button {
                            focusedField = nil
                            viewModel.connect()
                        } label: {
                            Text("connect")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            Section("section.message") {
                TextField("field.message.placeholder", text: $viewModel.message, axis: .vertical)
                    .lineLimit(3...6)
                    .focused($focusedField, equals: .message)

                Button {
                    focusedField = nil
                    if viewModel.sendMessage() {
                        showToast("toast.sent")
                    }
                } label: {
                    Label("send.to_vrchat", systemImage: "paperplane.fill")
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
                    "history.empty.title",
                    systemImage: "clock",
                    description: Text("history.empty.description")
                )
            } else {
                Section {
                    ForEach(viewModel.sendHistory, id: \.self) { historyItem in
                        Button {
                            guard !viewModel.sendHistoryImmediatelyEnabled || viewModel.isConnected else {
                                showToast("toast.connect_first")
                                return
                            }

                            let didSendMessage = viewModel.handleHistorySelection(historyItem)
                            if didSendMessage {
                                showToast("toast.sent")
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
                        Label("history.clear", systemImage: "trash")
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
                Toggle("settings.auto_connect", isOn: $viewModel.autoConnectOnLaunch)
            } footer: {
                Text("settings.auto_connect.footer")
            }

            Section {
                Toggle("settings.typing_indicator", isOn: $viewModel.sendTypingIndicatorEnabled)
            } footer: {
                Text("settings.typing_indicator.footer")
            }

            Section {
                Toggle("settings.live_preview", isOn: $viewModel.livePreviewEnabled)
            } footer: {
                Text("settings.live_preview.footer")
            }

            Section {
                Toggle("settings.history_immediate", isOn: $viewModel.sendHistoryImmediatelyEnabled)
            } footer: {
                Text("settings.history_immediate.footer")
            }
        }
    }

    private var historyFooterText: String {
        if viewModel.sendHistoryImmediatelyEnabled {
            L10n.text("history.footer.send_immediately")
        } else {
            L10n.text("history.footer.fill_message")
        }
    }

    private func showToast(_ key: String.LocalizationValue) {
        let localizedMessage = L10n.text(key)
        toastMessage = localizedMessage

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if toastMessage == localizedMessage {
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

                    Text("about.description")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            Section("about.version.section") {
                LabeledContent("about.current_version", value: appVersionText)
                LabeledContent("Bundle ID", value: bundleIdentifier)
            }

            Section("about.author.section") {
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
