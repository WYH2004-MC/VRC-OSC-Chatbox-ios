import AVFoundation
import Combine
import Speech
import SwiftUI
import UIKit

@MainActor
final class DictationModeController: ObservableObject {
    struct SendRecord: Identifiable {
        let id = UUID()
        let message: String
        let sentAt: Date
    }

    @Published private(set) var recognizedText = ""
    @Published private(set) var sendRecords: [SendRecord] = []
    @Published private(set) var statusText = L10n.text("dictation.status.ready")
    @Published private(set) var isRunning = false

    private let viewModel: ChatboxViewModel
    private let speechRecognizer = SFSpeechRecognizer()
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var sentTranscript = ""
    private var isStopping = false
    private var pendingSendTask: Task<Void, Never>?
    private var restartTask: Task<Void, Never>?
    private var recognitionGeneration = 0
    private var lastAudioActivityAt = Date.distantPast
    private let audioActivityThreshold: Float = 0.015
    private var originalBrightness = UIScreen.main.brightness
    private var originalIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
    private var brightenTask: Task<Void, Never>?

    init(viewModel: ChatboxViewModel) {
        self.viewModel = viewModel
    }

    func start() {
        guard !isRunning else {
            return
        }

        isRunning = true
        isStopping = false
        recognizedText = ""
        sendRecords = []
        sentTranscript = ""
        pendingSendTask?.cancel()
        pendingSendTask = nil
        restartTask?.cancel()
        restartTask = nil
        lastAudioActivityAt = .now
        enterDisplayMode()

        Task {
            await requestPermissionsAndStart()
        }
    }

    func stop() {
        guard isRunning || audioEngine.isRunning || recognitionTask != nil else {
            restoreDisplayMode()
            return
        }

        isStopping = true
        isRunning = false
        recognitionGeneration += 1
        pendingSendTask?.cancel()
        pendingSendTask = nil
        restartTask?.cancel()
        restartTask = nil
        stopRecognition()
        restoreDisplayMode()
        statusText = L10n.text("dictation.status.stopped")
    }

    func brightenTemporarily() {
        guard isRunning else {
            return
        }

        UIScreen.main.brightness = originalBrightness
        brightenTask?.cancel()
        brightenTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(5))
            } catch {
                return
            }

            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                guard let self, self.isRunning else {
                    return
                }

                UIScreen.main.brightness = 0
            }
        }
    }

    private func requestPermissionsAndStart() async {
        let speechAuthorized = await requestSpeechAuthorization()
        guard speechAuthorized else {
            statusText = L10n.text("dictation.error.speech_permission")
            return
        }

        let microphoneAuthorized = await requestMicrophoneAuthorization()
        guard microphoneAuthorized else {
            statusText = L10n.text("dictation.error.microphone_permission")
            return
        }

        startRecognition()
    }

    private func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func requestMicrophoneAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { isGranted in
                    continuation.resume(returning: isGranted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { isGranted in
                    continuation.resume(returning: isGranted)
                }
            }
        }
    }

    private func startRecognition() {
        guard isRunning, !isStopping else {
            return
        }

        guard viewModel.isConnected else {
            statusText = L10n.text("error.connect_first")
            return
        }

        guard speechRecognizer?.isAvailable == true else {
            statusText = L10n.text("dictation.error.unavailable")
            scheduleRestart()
            return
        }

        do {
            recognitionGeneration += 1
            let generation = recognitionGeneration
            stopRecognition()

            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            recognitionRequest = request

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                Task { @MainActor in
                    self?.updateAudioActivity(with: buffer)
                    self?.recognitionRequest?.append(buffer)
                }
            }

            audioEngine.prepare()
            try audioEngine.start()
            statusText = L10n.text("dictation.status.listening")

            recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    self?.handleRecognition(result: result, error: error, generation: generation)
                }
            }
        } catch {
            statusText = L10n.text("dictation.error.start_failed", error.localizedDescription)
            scheduleRestart()
        }
    }

    private func handleRecognition(
        result: SFSpeechRecognitionResult?,
        error: Error?,
        generation: Int
    ) {
        guard generation == recognitionGeneration else {
            return
        }

        if let result {
            let transcript = result.bestTranscription.formattedString
            recognizedText = transcript

            if result.isFinal {
                _ = sendRecognizedText(transcript)
                scheduleRestart()
            } else {
                scheduleSend(for: transcript)
            }
        }

        if error != nil {
            scheduleRestart()
        }
    }

    private func scheduleSend(for text: String) {
        pendingSendTask?.cancel()
        let generation = recognitionGeneration
        pendingSendTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(Int(self?.sendDelayMilliseconds ?? 1000)))
            } catch {
                return
            }

            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                guard let self, generation == self.recognitionGeneration else {
                    return
                }

                self.sendRecognizedTextAfterSilence(text)
            }
        }
    }

    private func sendRecognizedTextAfterSilence(_ text: String) {
        let quietDuration = Date.now.timeIntervalSince(lastAudioActivityAt)
        guard quietDuration >= viewModel.dictationSendDelay else {
            scheduleSend(for: text)
            return
        }

        if sendRecognizedText(text) {
            scheduleRestart()
        }
    }

    @discardableResult
    private func sendRecognizedText(_ text: String) -> Bool {
        pendingSendTask?.cancel()
        pendingSendTask = nil

        let textToSend = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textToSend.isEmpty else {
            return false
        }

        guard textToSend != sentTranscript else {
            return false
        }

        guard viewModel.sendTransientMessage(textToSend) else {
            statusText = viewModel.sendStatus
            return false
        }

        sentTranscript = textToSend
        sendRecords.insert(SendRecord(message: textToSend, sentAt: Date()), at: 0)
        statusText = L10n.text("dictation.status.listening")

        if sendRecords.count > 20 {
            sendRecords.removeLast(sendRecords.count - 20)
        }

        return true
    }

    private func updateAudioActivity(with buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else {
            return
        }

        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else {
            return
        }

        var sum: Float = 0
        for frame in 0..<frameLength {
            let sample = channelData[frame]
            sum += sample * sample
        }

        let rootMeanSquare = sqrt(sum / Float(frameLength))
        if rootMeanSquare > audioActivityThreshold {
            lastAudioActivityAt = .now
        }
    }

    private var sendDelayMilliseconds: Int {
        Int(viewModel.dictationSendDelay * 1000)
    }

    private func scheduleRestart() {
        guard isRunning, !isStopping else {
            return
        }

        recognitionGeneration += 1
        pendingSendTask?.cancel()
        pendingSendTask = nil
        restartTask?.cancel()
        stopRecognition()
        recognizedText = ""
        sentTranscript = ""
        statusText = L10n.text("dictation.status.restarting")

        restartTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(450))
            } catch {
                return
            }

            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                self?.startRecognition()
            }
        }
    }

    private func stopRecognition() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func enterDisplayMode() {
        originalBrightness = UIScreen.main.brightness
        originalIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
        UIScreen.main.brightness = 0
    }

    private func restoreDisplayMode() {
        brightenTask?.cancel()
        brightenTask = nil
        UIScreen.main.brightness = originalBrightness
        UIApplication.shared.isIdleTimerDisabled = originalIdleTimerDisabled
    }
}
