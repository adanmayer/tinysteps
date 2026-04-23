import AVFoundation
import Foundation
import Combine

@MainActor
final class ChildVoiceCaptureViewModel: NSObject, ObservableObject, AVAudioPlayerDelegate {
    enum State: Equatable {
        case askingAssent
        case ready
        case recording
        case recorded
        case savingLocalDraft
        case saved
        case failed(String)
    }

    @Published private(set) var state: State = .askingAssent
    @Published private(set) var recordingTimeText: String = "00:00"
    @Published private(set) var isPlaying = false

    let session: ChildVoiceCaptureSession
    private let recorder: ChildVoiceAudioRecording

    private let maxDuration: TimeInterval
    private var recordedDuration: TimeInterval = 0
    private var recordingFilename: String?
    private var timerTask: Task<Void, Never>?
    private var audioPlayer: AVAudioPlayer?
    private(set) var savedDraft: ChildVoiceDraft?

    init(
        session: ChildVoiceCaptureSession,
        maxDuration: TimeInterval = 30,
        recorder: ChildVoiceAudioRecording? = nil
    ) {
        self.session = session
        self.maxDuration = maxDuration
        self.recorder = recorder ?? ChildVoiceAudioRecorder()
        super.init()
    }

    var childName: String {
        session.child.displayName
    }

    func begin() async {
        guard case .askingAssent = state else {
            return
        }

        let hasPermission = await recorder.requestMicrophonePermission()
        guard hasPermission else {
            state = .failed("Microphone access is required to record.")
            return
        }

        state = .ready
    }

    func startRecording() {
        guard state == .ready else {
            return
        }
        timerTask?.cancel()
        isPlaying = false
        audioPlayer?.pause()
        audioPlayer?.currentTime = 0

        do {
            recordingFilename = try recorder.startRecording()
            recordedDuration = 0
            updateRecordingTimeText(0)
            state = .recording
            startTimer()
        } catch {
            state = .failed((error as? LocalizedError)?.errorDescription ?? "Unable to start recording.")
        }
    }

    func stopRecording() {
        guard state == .recording else {
            return
        }
        timerTask?.cancel()

        do {
            let result = try recorder.stopRecording()
            recordingFilename = result.localFilename
            recordedDuration = min(result.duration, maxDuration)
            updateRecordingTimeText(recordedDuration)
            state = .recorded
        } catch {
            state = .failed((error as? LocalizedError)?.errorDescription ?? "Unable to stop recording.")
        }
    }

    func discardRecording() {
        stopPlayback()
        timerTask?.cancel()

        if let recordingFilename {
            try? recorder.deleteRecording(filename: recordingFilename)
        }
        recordingFilename = nil
        recordedDuration = 0
        savedDraft = nil
        updateRecordingTimeText(0)
        state = .ready
    }

    func resetToReady() {
        discardRecording()
    }

    func rerecord() {
        discardRecording()
    }

    func saveDraft() {
        guard state == .recorded else {
            return
        }
        guard let recordingFilename else {
            state = .failed("No recording available to save.")
            return
        }

        state = .savingLocalDraft

        savedDraft = ChildVoiceDraft(
            localFilename: recordingFilename,
            childStudentKey: session.child.studentKey,
            childUserID: session.child.userID,
            childDisplayName: session.child.displayName,
            duration: recordedDuration,
            createdAt: Date()
        )
        state = .saved
    }

    func togglePlayback() {
        guard state == .recorded || state == .saved else {
            return
        }
        guard let recordingFilename else {
            return
        }
        let url = recorder.resolveRecordingURL(for: recordingFilename)

        if isPlaying {
            audioPlayer?.pause()
            isPlaying = false
            return
        }

        do {
            if audioPlayer == nil || audioPlayer?.url != url {
                let player = try AVAudioPlayer(contentsOf: url)
                player.delegate = self
                player.prepareToPlay()
                audioPlayer = player
            }
            audioPlayer?.play()
            isPlaying = true
        } catch {
            state = .failed("Unable to play recording.")
        }
    }

    func cancel() {
        timerTask?.cancel()
        stopPlayback()
        if case .recording = state {
            try? recorder.cancelRecording()
        }
        discardRecording()
        state = .askingAssent
    }

    func cancelIfNeeded() {
        timerTask?.cancel()
        if state == .recording {
            try? recorder.cancelRecording()
        }
        stopPlayback()
    }

    private func stopPlayback() {
        isPlaying = false
        audioPlayer?.pause()
        audioPlayer?.currentTime = 0
        audioPlayer = nil
    }

    private func updateRecordingTimeText(_ duration: TimeInterval) {
        let safeDuration = max(0, duration)
        let seconds = Int(safeDuration)
        let minutes = seconds / 60
        let remainder = seconds % 60
        recordingTimeText = String(format: "%d:%02d", minutes, remainder)
    }

    private func startTimer() {
        let startedAt = Date()
        timerTask = Task { [weak self] in
            guard let self else {
                return
            }

            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                await MainActor.run {
                    guard self.state == .recording else {
                        return
                    }
                    let elapsed = Date().timeIntervalSince(startedAt)
                    let clamped = min(elapsed, self.maxDuration)
                    self.recordedDuration = clamped
                    self.updateRecordingTimeText(clamped)

                    if elapsed >= self.maxDuration {
                        self.stopRecording()
                    }
                }
            }
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully: Bool) {
        guard state == .recorded || state == .saved else {
            return
        }
        isPlaying = false
    }
}
