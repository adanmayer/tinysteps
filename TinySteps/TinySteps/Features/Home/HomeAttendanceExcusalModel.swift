import Foundation
import MBAPI
import Observation

@Observable
@MainActor
final class HomeAttendanceExcusalModel {
    private(set) var isLoading = false
    private(set) var isSubmitting = false
    private(set) var isAttendanceExcusalEnabled = false
    private(set) var errorMessage: String?
    private(set) var didSubmitAttendanceExcusal = false

    private let session: AuthSession
    private let parentAssociationService: ParentAssociationService
    private var hasLoadedAvailability = false

    init(
        session: AuthSession,
        parentAssociationService: ParentAssociationService
    ) {
        self.session = session
        self.parentAssociationService = parentAssociationService
    }

    func loadIfNeeded() async {
        guard hasLoadedAvailability == false else {
            return
        }

        await reload()
    }

    func reload() async {
        isLoading = true
        errorMessage = nil
        didSubmitAttendanceExcusal = false

        hasLoadedAvailability = true

        do {
            let school = try await parentAssociationService.loadSchool(for: session)
            isAttendanceExcusalEnabled = school.attendanceEnabled && school.parentExcusalsEnabled
        } catch {
            hasLoadedAvailability = false
            isAttendanceExcusalEnabled = false
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func submit(
        for childContext: ChildContext,
        startDate: Date,
        duration: Int,
        reason: String
    ) async -> Bool {
        isSubmitting = true
        defer {
            isSubmitting = false
        }

        let trimmedReason = reason
            .trimmingCharacters(in: .whitespacesAndNewlines)

        errorMessage = nil
        didSubmitAttendanceExcusal = false

        guard isAttendanceExcusalEnabled else {
            errorMessage = "Attendance excusal is not available for this child context."
            return false
        }

        guard trimmedReason.isEmpty == false else {
            errorMessage = "Please add a reason before submitting."
            return false
        }

        do {
            let payload = MBAttendanceExcusalSubmission(
                startDate: startDate,
                duration: duration,
                comment: trimmedReason
            )
            try await parentAssociationService.submitAttendanceExcusal(
                for: session,
                childContext: childContext,
                submission: payload
            )
            didSubmitAttendanceExcusal = true
            return true
        } catch {
            errorMessage = error.localizedDescription
            didSubmitAttendanceExcusal = false
            return false
        }
    }

    func prepareForNewSubmission() {
        errorMessage = nil
        didSubmitAttendanceExcusal = false
    }

    func clearErrorMessage() {
        errorMessage = nil
    }
}
