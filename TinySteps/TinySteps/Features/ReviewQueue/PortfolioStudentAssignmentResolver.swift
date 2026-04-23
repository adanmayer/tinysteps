import Foundation

struct PortfolioStudentAssignmentReference: Sendable {
    let studentKey: String
    let userID: String?
}

struct PortfolioStudentAssignmentResolver: Sendable {
    func assignedUserIDs(
        for selectedStudents: [PortfolioStudentAssignmentReference]
    ) throws -> [Int] {
        let references = selectedStudents.filter { reference in
            reference.studentKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
            (reference.userID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        }

        guard references.isEmpty == false else {
            return []
        }

        var seen: Set<Int> = []
        var result: [Int] = []
        for reference in references {
            guard let rawUserID = reference.userID?.trimmingCharacters(in: .whitespacesAndNewlines),
                  rawUserID.isEmpty == false,
                  let userID = Int(rawUserID)
            else {
                throw ObservationDraftPublishError.validation("A selected student has no publishable user id. Clear local drafts and capture again.")
            }

            guard seen.insert(userID).inserted else {
                continue
            }

            result.append(userID)
        }
        return result
    }
}
