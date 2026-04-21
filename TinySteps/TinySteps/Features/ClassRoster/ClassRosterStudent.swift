import Foundation
import MBAPI

struct ClassRosterStudent: Identifiable, Equatable, Sendable {
    let id: String
    let studentKey: String
    let displayName: String
    let firstName: String
    let initials: String
    let avatarURL: URL?
    let enrollmentStatus: FaceEnrollmentStatus
    let todayObservationCount: Int?
    let presence: ClassRosterPresence

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
