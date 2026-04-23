import AVFoundation
import Foundation

protocol ChildVoiceAudioRecording {
    func requestMicrophonePermission() async -> Bool
    func startRecording() throws -> String
    func stopRecording() throws -> ChildVoiceRecordingResult
    func cancelRecording() throws
    func resolveRecordingURL(for filename: String) -> URL
    func deleteRecording(filename: String) throws
    func recordingData(for filename: String) throws -> Data
}

struct ChildVoiceRecordingResult: Sendable {
    let localFilename: String
    let duration: TimeInterval
    let createdAt: Date
}

enum ChildVoiceAudioRecorderError: LocalizedError, Equatable, Sendable {
    case permissionDenied
    case unableToPrepareDirectory
    case unableToPrepareRecording
    case failedToStartRecording
    case noActiveRecording
    case failedToReadRecording
    case failedToDeleteRecording(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Microphone access is required to record a child's voice."
        case .unableToPrepareDirectory:
            "Failed to prepare the local recording location."
        case .unableToPrepareRecording:
            "Failed to prepare recording."
        case .failedToStartRecording:
            "Recording could not be started."
        case .noActiveRecording:
            "There is no active recording to stop."
        case .failedToReadRecording:
            "Failed to load the recorded audio file."
        case .failedToDeleteRecording(let filename):
            "Could not delete audio file \(filename)."
        }
    }
}

final class ChildVoiceAudioRecorder: NSObject, ChildVoiceAudioRecording {
    private enum Constants {
        static let recordingDirectory = "ChildVoice"
        static let audioFormat = "m4a"
    }

    private let fileManager: FileManager
    private let baseDirectory: URL
    private var recorder: AVAudioRecorder?
    private var currentFilename: String?

    init(fileManager: FileManager = .default, baseDirectory: URL? = nil) {
        self.fileManager = fileManager
        if let baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            self.baseDirectory = Self.defaultDirectory()
        }
    }

    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { allowed in
                    continuation.resume(returning: allowed)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                    continuation.resume(returning: allowed)
                }
            }
        }
    }

    func startRecording() throws -> String {
        guard ensureDirectoryReady() else {
            throw ChildVoiceAudioRecorderError.unableToPrepareDirectory
        }

        let filename = Self.makeFilename()
        let fileURL = resolveRecordingURL(for: filename)
        let audioSession = AVAudioSession.sharedInstance()

        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 96_000
        ]

        do {
            let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
            recorder.prepareToRecord()
            guard recorder.record() else {
                throw ChildVoiceAudioRecorderError.failedToStartRecording
            }
            self.recorder = recorder
            self.currentFilename = filename
            return filename
        } catch {
            throw ChildVoiceAudioRecorderError.unableToPrepareRecording
        }
    }

    func stopRecording() throws -> ChildVoiceRecordingResult {
        guard let recorder, let filename = currentFilename else {
            throw ChildVoiceAudioRecorderError.noActiveRecording
        }

        recorder.stop()
        self.recorder = nil
        self.currentFilename = nil
        let url = resolveRecordingURL(for: filename)
        try? fileManager.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: url.path
        )
        return ChildVoiceRecordingResult(
            localFilename: filename,
            duration: recorder.currentTime,
            createdAt: Date()
        )
    }

    func cancelRecording() throws {
        guard let filename = currentFilename else {
            return
        }
        recorder?.stop()
        recorder = nil
        currentFilename = nil
        try deleteRecording(filename: filename)
    }

    func resolveRecordingURL(for filename: String) -> URL {
        baseDirectory.appendingPathComponent(filename)
    }

    func deleteRecording(filename: String) throws {
        let url = resolveRecordingURL(for: filename)
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw ChildVoiceAudioRecorderError.failedToDeleteRecording(filename)
        }
    }

    func recordingData(for filename: String) throws -> Data {
        let url = resolveRecordingURL(for: filename)
        do {
            return try Data(contentsOf: url)
        } catch {
            throw ChildVoiceAudioRecorderError.failedToReadRecording
        }
    }

    private func ensureDirectoryReady() -> Bool {
        do {
            try fileManager.createDirectory(
                at: baseDirectory,
                withIntermediateDirectories: true
            )
            try fileManager.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: baseDirectory.path
            )
            return true
        } catch {
            return false
        }
    }

    private static func defaultDirectory() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return appSupport
            .appendingPathComponent("TinySteps", isDirectory: true)
            .appendingPathComponent(Constants.recordingDirectory, isDirectory: true)
    }

    private static func makeFilename() -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        return "child-voice-\(timestamp)-\(UUID().uuidString).\(Constants.audioFormat)"
    }
}
