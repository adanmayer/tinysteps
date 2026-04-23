import Foundation
import MBAPI

struct ClassRosterStudent: Identifiable, Equatable, Sendable {
    let id: String
    let studentKey: String
    let userID: String?
    let displayName: String
    let firstName: String
    let initials: String
    let avatarURL: URL?
    let enrollmentStatus: FaceEnrollmentStatus
    let todayObservationCount: Int?
    let presence: ClassRosterPresence

    init(
        id: String,
        studentKey: String,
        userID: String? = nil,
        displayName: String,
        firstName: String,
        initials: String,
        avatarURL: URL?,
        enrollmentStatus: FaceEnrollmentStatus,
        todayObservationCount: Int?,
        presence: ClassRosterPresence
    ) {
        self.id = id
        self.studentKey = studentKey
        self.userID = userID
        self.displayName = displayName
        self.firstName = firstName
        self.initials = initials
        self.avatarURL = avatarURL
        self.enrollmentStatus = enrollmentStatus
        self.todayObservationCount = todayObservationCount
        self.presence = presence
    }

    var isFaceEnrolled: Bool {
        if case .enrolled = enrollmentStatus {
            return true
        }

        return false
    }

    var needsFaceEnrollment: Bool {
        enrollmentStatus.needsSetup
    }

    var observationCountText: String {
        if let todayObservationCount, todayObservationCount > 0 {
            return "\(todayObservationCount)"
        }
        return "—"
    }

    var accessibilityLabel: String {
        let presenceText = presence == .present ? "present today" : "absent today"
        if isFaceEnrolled {
            return "\(displayName), face setup complete, \(observationCountText) observations, \(presenceText)"
        }
        return "\(displayName), face setup needed, \(presenceText)"
    }

    static func from(member: MBMember, status: FaceEnrollmentStatus, presence: ClassRosterPresence) -> ClassRosterStudent {
        let fullName = member.displayName
        let providedInitials = member.user.initials?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let fallbackInitials = String(
            fullName
                .split(separator: " ")
                .compactMap { $0.first }
                .map(String.init)
                .joined()
                .prefix(2)
        )
        let initials = providedInitials.isEmpty ? fallbackInitials : providedInitials

        return ClassRosterStudent(
            id: member.rosterStudentKey,
            studentKey: member.rosterStudentKey,
            userID: member.user.id,
            displayName: fullName,
            firstName: member.firstNameFromDisplayName,
            initials: String(initials),
            avatarURL: member.user.avatarURL,
            enrollmentStatus: status,
            todayObservationCount: nil,
            presence: presence
        )
    }
}
