import SwiftUI

struct DictationModeView: View {
    @StateObject private var controller: DictationModeController
    let onExit: () -> Void

    init(viewModel: ChatboxViewModel, onExit: @escaping () -> Void) {
        _controller = StateObject(wrappedValue: DictationModeController(viewModel: viewModel))
        self.onExit = onExit
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    controller.brightenTemporarily()
                }

            VStack(spacing: 16) {
                Spacer()

                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.white.opacity(0.18))
                    .padding(.bottom, 12)

                recognitionPanel
                    .padding(.horizontal, 20)

                Button {
                    controller.stop()
                    onExit()
                } label: {
                    Label("dictation.exit", systemImage: "xmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
                .padding(.horizontal, 36)
                .padding(.bottom, 28)
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear {
            controller.start()
        }
        .onDisappear {
            controller.stop()
        }
    }

    private var recognitionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: controller.isRunning ? "waveform" : "mic.slash")
                    .foregroundStyle(.green)

                Text(controller.statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("dictation.current_result")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(controller.recognizedText.isEmpty ? L10n.text("dictation.no_result") : controller.recognizedText)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(3)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("dictation.send_records")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if controller.sendRecords.isEmpty {
                    Text("dictation.no_records")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(controller.sendRecords) { record in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(record.message)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)

                                    Text(record.sentAt.formatted(.dateTime.hour().minute().second()))
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .frame(maxHeight: 180)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .colorScheme(.dark)
    }
}

#Preview {
    DictationModeView(viewModel: ChatboxViewModel()) {}
}
