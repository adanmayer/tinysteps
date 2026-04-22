import AVFoundation
import Foundation
import Speech

struct ObservationTranscriptEvent: Equatable, Sendable {
    let transcript: String
    let isFinal: Bool
}

protocol ObservationSpeechTranscribing: Sendable {
    func requestAuthorization() async -> ObservationSpeechAuthorizationStatus
    func start(locale: Locale) async throws -> AsyncThrowingStream<ObservationTranscriptEvent, Error>
    func stop() async -> String
    func cancel() async
}

enum ObservationSpeechTranscriberError: LocalizedError, Sendable {
    case recognizerUnavailable
    case onDeviceRecognitionUnavailable
    case audioEngineUnavailable
    case recognitionFailed(String)
    case recordingInterrupted(String)

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Speech recognition is unavailable for the current locale."
        case .onDeviceRecognitionUnavailable:
            return "On-device speech recognition is unavailable on this device."
        case .audioEngineUnavailable:
            return "The microphone could not be started."
        case .recognitionFailed(let message):
            return message
        case .recordingInterrupted(let message):
            return message
        }
    }

    var isRecoverableRecordingInterruption: Bool {
        if case .recordingInterrupted = self {
            return true
        }

        return false
    }
}

final class AppleObservationSpeechTranscriber: ObservationSpeechTranscribing, @unchecked Sendable {
    private let queue = DispatchQueue(label: "co.faria.TinySteps.ObservationSpeechTranscriber")
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var streamContinuation: AsyncThrowingStream<ObservationTranscriptEvent, Error>.Continuation?
    private var latestTranscript = ""
    private var hasInstalledTap = false
    private var audioSessionObservers: [NSObjectProtocol] = []
    private var pendingStopContinuation: CheckedContinuation<String, Never>?
    private var pendingStopTimeout: DispatchWorkItem?

    func requestAuthorization() async -> ObservationSpeechAuthorizationStatus {
        let speechStatus = await requestSpeechAuthorization()
        guard speechStatus == .authorized else {
            return speechStatus
        }

        let microphoneAllowed = await requestMicrophoneAuthorization()
        return microphoneAllowed ? .authorized : .microphoneDenied
    }

    func start(locale: Locale) async throws -> AsyncThrowingStream<ObservationTranscriptEvent, Error> {
        let stream = AsyncThrowingStream<ObservationTranscriptEvent, Error> { continuation in
            queue.async {
                self.streamContinuation = continuation
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    try self.startRecognition(locale: locale)
                    continuation.resume(returning: stream)
                } catch {
                    self.cleanup(cancelTask: true, finishStream: false)
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stop() async -> String {
        await withCheckedContinuation { continuation in
            queue.async {
                guard self.recognitionRequest != nil || self.recognitionTask != nil || self.audioEngine != nil else {
                    let transcript = self.latestTranscript
                    self.cleanup(cancelTask: false, finishStream: true)
                    continuation.resume(returning: transcript)
                    return
                }

                self.pendingStopContinuation?.resume(returning: self.latestTranscript)
                self.pendingStopTimeout?.cancel()
                self.pendingStopContinuation = continuation
                self.endAudioForPendingStop()

                let timeout = DispatchWorkItem { [weak self] in
                    self?.completePendingStop()
                }
                self.pendingStopTimeout = timeout
                self.queue.asyncAfter(deadline: .now() + 0.8, execute: timeout)
            }
        }
    }

    func cancel() async {
        await withCheckedContinuation { continuation in
            queue.async {
                let pendingStopContinuation = self.pendingStopContinuation
                self.pendingStopContinuation = nil
                self.pendingStopTimeout?.cancel()
                self.pendingStopTimeout = nil
                self.latestTranscript = ""
                self.cleanup(cancelTask: true, finishStream: true)
                pendingStopContinuation?.resume(returning: "")
                continuation.resume()
            }
        }
    }

    private func requestSpeechAuthorization() async -> ObservationSpeechAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: Self.mapSpeechStatus(status))
            }
        }
    }

    private func requestMicrophoneAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
    }

    private static func mapSpeechStatus(_ status: SFSpeechRecognizerAuthorizationStatus) -> ObservationSpeechAuthorizationStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .authorized:
            return .authorized
        @unknown default:
            return .unknown
        }
    }

    private func startRecognition(locale: Locale) throws {
        cleanup(cancelTask: true, finishStream: false)
        latestTranscript = ""

        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw ObservationSpeechTranscriberError.recognizerUnavailable
        }

        guard recognizer.supportsOnDeviceRecognition else {
            throw ObservationSpeechTranscriberError.onDeviceRecognitionUnavailable
        }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        beginObservingAudioSession()

        let audioEngine = AVAudioEngine()
        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true
        recognitionRequest.taskHint = .dictation

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        guard recordingFormat.channelCount > 0 else {
            throw ObservationSpeechTranscriberError.audioEngineUnavailable
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        hasInstalledTap = true

        audioEngine.prepare()
        try audioEngine.start()

        self.audioEngine = audioEngine
        self.recognitionRequest = recognitionRequest
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { result, error in
            let transcript = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let recognitionError = error.map {
                ObservationSpeechTranscriberError.recognitionFailed($0.localizedDescription)
            }

            self.queue.async {
                if let transcript {
                    self.latestTranscript = transcript
                    self.streamContinuation?.yield(
                        ObservationTranscriptEvent(
                            transcript: transcript,
                            isFinal: isFinal
                        )
                    )
                }

                if let recognitionError {
                    if self.pendingStopContinuation != nil {
                        self.completePendingStop()
                    } else {
                        self.finishStreamWithError(recognitionError)
                    }
                    return
                }

                if isFinal {
                    self.completePendingStop()
                }
            }
        }
    }

    private func beginObservingAudioSession() {
        removeAudioSessionObservers()

        let notificationCenter = NotificationCenter.default
        let audioSession = AVAudioSession.sharedInstance()
        audioSessionObservers = [
            notificationCenter.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: audioSession,
                queue: nil
            ) { [weak self] notification in
                self?.queue.async {
                    self?.handleAudioSessionInterruption(notification)
                }
            },
            notificationCenter.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: audioSession,
                queue: nil
            ) { [weak self] notification in
                self?.queue.async {
                    self?.handleAudioSessionRouteChange(notification)
                }
            },
            notificationCenter.addObserver(
                forName: AVAudioSession.mediaServicesWereResetNotification,
                object: audioSession,
                queue: nil
            ) { [weak self] _ in
                self?.queue.async {
                    self?.finishStreamWithError(
                        .recordingInterrupted("Recording stopped because audio services were reset.")
                    )
                }
            }
        ]
    }

    private func removeAudioSessionObservers() {
        let notificationCenter = NotificationCenter.default
        for observer in audioSessionObservers {
            notificationCenter.removeObserver(observer)
        }
        audioSessionObservers = []
    }

    private func handleAudioSessionInterruption(_ notification: Notification) {
        guard
            let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            AVAudioSession.InterruptionType(rawValue: typeValue) == .began
        else {
            return
        }

        finishStreamWithError(
            .recordingInterrupted("Recording stopped because another audio session interrupted the microphone.")
        )
    }

    private func handleAudioSessionRouteChange(_ notification: Notification) {
        guard
            let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
        else {
            return
        }

        guard shouldStopRecordingForRouteChange(reason) else {
            return
        }

        finishStreamWithError(
            .recordingInterrupted("Recording stopped because the microphone became unavailable.")
        )
    }

    private func shouldStopRecordingForRouteChange(_ reason: AVAudioSession.RouteChangeReason) -> Bool {
        switch reason {
        case .noSuitableRouteForCategory:
            return true
        case .oldDeviceUnavailable:
            return AVAudioSession.sharedInstance().currentRoute.inputs.isEmpty
        case .unknown,
             .newDeviceAvailable,
             .categoryChange,
             .override,
             .wakeFromSleep,
             .routeConfigurationChange:
            return false
        @unknown default:
            return false
        }
    }

    private func finishStreamWithError(_ error: ObservationSpeechTranscriberError) {
        guard recognitionRequest != nil || recognitionTask != nil || audioEngine != nil else {
            return
        }

        if pendingStopContinuation != nil {
            completePendingStop()
            return
        }

        streamContinuation?.finish(throwing: error)
        streamContinuation = nil
        cleanup(cancelTask: true, finishStream: false)
    }

    private func endAudioForPendingStop() {
        if hasInstalledTap {
            audioEngine?.inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }

        audioEngine?.stop()
        recognitionRequest?.endAudio()
    }

    private func completePendingStop() {
        guard let continuation = pendingStopContinuation else {
            return
        }

        pendingStopContinuation = nil
        pendingStopTimeout?.cancel()
        pendingStopTimeout = nil

        let transcript = latestTranscript
        cleanup(cancelTask: false, finishStream: true)
        continuation.resume(returning: transcript)
    }

    private func cleanup(cancelTask: Bool, finishStream: Bool) {
        removeAudioSessionObservers()
        pendingStopTimeout?.cancel()
        pendingStopTimeout = nil

        if hasInstalledTap {
            audioEngine?.inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }

        audioEngine?.stop()
        recognitionRequest?.endAudio()

        if cancelTask {
            recognitionTask?.cancel()
        } else {
            recognitionTask?.finish()
        }

        recognitionTask = nil
        recognitionRequest = nil
        audioEngine = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        if finishStream {
            streamContinuation?.finish()
            streamContinuation = nil
        }
    }
}

struct PreviewObservationSpeechTranscriber: ObservationSpeechTranscribing {
    let scriptedTranscript: String

    init(scriptedTranscript: String = "") {
        self.scriptedTranscript = scriptedTranscript
    }

    func requestAuthorization() async -> ObservationSpeechAuthorizationStatus {
        .authorized
    }

    func start(locale: Locale) async throws -> AsyncThrowingStream<ObservationTranscriptEvent, Error> {
        AsyncThrowingStream { continuation in
            if scriptedTranscript.isEmpty == false {
                continuation.yield(
                    ObservationTranscriptEvent(
                        transcript: scriptedTranscript,
                        isFinal: false
                    )
                )
            }
        }
    }

    func stop() async -> String {
        scriptedTranscript
    }

    func cancel() async {}
}
