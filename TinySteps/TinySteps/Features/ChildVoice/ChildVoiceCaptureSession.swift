import Foundation

struct ChildVoiceCaptureSession: Equatable, Sendable {
    let mode: ChildVoiceCaptureMode
    let maxDuration: TimeInterval

    init(mode: ChildVoiceCaptureMode, maxDuration: TimeInterval = 30) {
        self.mode = mode
        self.maxDuration = maxDuration
    }

    var classID: String {
        switch mode {
        case .photoAttachment(let classID, _, _),
             .standaloneNote(let classID, _, _):
            classID
        }
    }

    var className: String {
        switch mode {
        case .photoAttachment(_, let className, _),
             .standaloneNote(_, let className, _):
            className
        }
    }

    var child: ChildVoiceChild {
        switch mode {
        case .photoAttachment(_, _, let child),
             .standaloneNote(_, _, let child):
            child
        }
    }
}
