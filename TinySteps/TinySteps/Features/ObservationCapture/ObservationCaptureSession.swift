import Foundation
import MBAPI

struct ObservationCaptureLaunchContext: Equatable, Sendable {
    let classID: String
    let className: String
    let selectedClass: MBClass
    let rosterSnapshot: [ObservationRosterStudent]
}

struct ObservationCaptureSession: Identifiable, Equatable, Sendable {
    let id: UUID
    let classID: String
    let className: String
    let selectedClass: MBClass
    let rosterSnapshot: [ObservationRosterStudent]
    let initialDraftID: ObservationCaptureDraft.ID?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        classID: String,
        className: String,
        selectedClass: MBClass,
        rosterSnapshot: [ObservationRosterStudent],
        initialDraftID: ObservationCaptureDraft.ID? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.classID = classID
        self.className = className
        self.selectedClass = selectedClass
        self.rosterSnapshot = rosterSnapshot
        self.initialDraftID = initialDraftID
        self.createdAt = createdAt
    }

    init(launchContext: ObservationCaptureLaunchContext, initialDraftID: ObservationCaptureDraft.ID? = nil) {
        self.init(
            classID: launchContext.classID,
            className: launchContext.className,
            selectedClass: launchContext.selectedClass,
            rosterSnapshot: launchContext.rosterSnapshot,
            initialDraftID: initialDraftID
        )
    }
}

struct ObservationRosterStudent: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let studentKey: String
    let displayName: String
    let firstName: String
    let initials: String

    init(
        id: String,
        studentKey: String,
        displayName: String,
        firstName: String,
        initials: String
    ) {
        self.id = id
        self.studentKey = studentKey
        self.displayName = displayName
        self.firstName = firstName
        self.initials = initials
    }

    init(from student: ClassRosterStudent) {
        self.init(
            id: student.id,
            studentKey: student.studentKey,
            displayName: student.displayName,
            firstName: student.firstName,
            initials: student.initials
        )
    }
}

#if DEBUG
extension ObservationCaptureSession {
    static let preview = ObservationCaptureSession(
        id: UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee") ?? UUID(),
        classID: "class-caterpillars",
        className: "Caterpillars room",
        selectedClass: MBClass(
            id: "class-caterpillars",
            displayName: "Caterpillars room",
            iconName: "",
            isLocked: false,
            isMember: true,
            program: MBClassProgram(code: "PYP", name: "Primary Years Programme"),
            terms: []
        ),
        rosterSnapshot: [
            ObservationRosterStudent(
                id: "amara",
                studentKey: "amara",
                displayName: "Amara",
                firstName: "Amara",
                initials: "A"
            ),
            ObservationRosterStudent(
                id: "finn",
                studentKey: "finn",
                displayName: "Finn",
                firstName: "Finn",
                initials: "F"
            )
        ]
    )
}
#endif
