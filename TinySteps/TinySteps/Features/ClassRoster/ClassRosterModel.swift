import Foundation
import MBAPI
import Observation

@Observable
@MainActor
final class ClassRosterModel {
    private(set) var students: [ClassRosterStudent] = []
    private(set) var searchText: String = ""
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var localStatusErrorMessage: String?

    private let session: AuthSession
    private let classesService: ClassesService
    private let faceEnrollmentStore: FaceEnrollmentStore
    private var hasLoaded = false
    private var loadedClassID: String?

    init(
        session: AuthSession,
        classesService: ClassesService,
        faceEnrollmentStore: FaceEnrollmentStore
    ) {
        self.session = session
        self.classesService = classesService
        self.faceEnrollmentStore = faceEnrollmentStore
    }

    func setSearchText(_ text: String) {
        searchText = text
    }

    func loadIfNeeded(for selectedClass: MBClass?, classContext: ClassContext) async {
        let classID = selectedClass?.id
        guard case .schoolClass(let contextClassID) = classContext, contextClassID == classID else {
            students = []
            searchText = ""
            hasLoaded = true
            loadedClassID = nil
            localStatusErrorMessage = nil
            errorMessage = nil
            return
        }
        if hasLoaded, loadedClassID == classID {
            return
        }
        await load(classID: classID)
    }

    func reload(for selectedClass: MBClass?) async {
        await load(classID: selectedClass?.id)
    }

    private func load(classID: String?) async {
        guard let classID else {
            students = []
            searchText = ""
            errorMessage = nil
            localStatusErrorMessage = nil
            isLoading = false
            hasLoaded = true
            loadedClassID = nil
            return
        }

        searchText = ""

        isLoading = true
        errorMessage = nil
        localStatusErrorMessage = nil

        do {
            let members = try await classesService.loadClassStudents(for: session, classID: classID)
            let memberKeys = members.map { $0.rosterStudentKey }
            var statuses: [String: FaceEnrollmentStatus] = [:]
            do {
                statuses = try await faceEnrollmentStore.statuses(for: memberKeys)
            } catch {
                localStatusErrorMessage = "Face setup status is unavailable on this device right now."
                for memberKey in memberKeys {
                    statuses[memberKey] = .unavailable
                }
            }

            students = members
                .sorted { $0.rosterStudentKey < $1.rosterStudentKey }
                .map { member in
                    ClassRosterStudent.from(
                        member: member,
                        status: statuses[member.rosterStudentKey] ?? .needsSetup,
                        presence: .present
                    )
                }
            loadedClassID = classID
            hasLoaded = true
        } catch {
            students = []
            errorMessage = error.localizedDescription
            localStatusErrorMessage = nil
        }

        isLoading = false
    }

    var filteredStudents: [ClassRosterStudent] {
        let query = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard query.isEmpty == false else {
            return students
        }

        return students.filter { student in
            student.displayName.lowercased().contains(query) ||
            student.initials.lowercased().contains(query) ||
            student.firstName.lowercased().contains(query)
        }
    }

    var presentStudents: [ClassRosterStudent] {
        filteredStudents.filter { $0.presence == .present }
    }

    var notInTodayStudents: [ClassRosterStudent] {
        filteredStudents.filter { $0.presence == .notInToday }
    }

    var awaitingFaceEnrollmentCount: Int {
        students.filter(\.needsFaceEnrollment).count
    }

    var headerMetaText: String {
        "\(students.count) children - \(awaitingFaceEnrollmentCount) awaiting face enrolment"
    }

    var isSearchEmpty: Bool {
        searchText.isEmpty == false && filteredStudents.isEmpty
    }
}
