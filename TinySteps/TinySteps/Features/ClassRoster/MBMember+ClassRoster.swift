import Foundation
import MBAPI

extension MBMember {
    var rosterStudentKey: String {
        if let studentID, studentID.isEmpty == false {
            return studentID
        }

        return user.id
    }

    var displayName: String {
        user.fullName
    }

    var firstNameFromDisplayName: String {
        let parts = user.fullName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .map(String.init)

        return parts.first ?? user.fullName
    }
}

