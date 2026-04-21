import Testing
import Foundation
@testable import TinySteps
import MBAPI

@MainActor
struct ClassRosterModelTests {
    @Test("Loads only selected class members and maps missing statuses as needs setup")
    func loadsSelectedClassMembers() async throws {
        let membersByClass = [
            "class-1": [
                MBMember(
                    id: "member-1",
                    user: MBMemberUser(
                        id: "user-1",
                        fullName: "Alice Zephyr",
                        initials: "AZ"
                    ),
                    studentID: "student-1"
                ),
                MBMember(
                    id: "member-2",
                    user: MBMemberUser(
                        id: "user-2",
                        fullName: "Ben Orbit",
                        initials: "BO"
                    ),
                    studentID: nil
                )
            ],
            "class-2": [
                MBMember(
                    id: "member-3",
                    user: MBMemberUser(
                        id: "user-3",
                        fullName: "Carol Zane",
                        initials: "CZ"
                    ),
                    studentID: "student-3"
                )
            ]
        ]

        let classesService = MockClassRosterClassesService(membersByClass: membersByClass)
        let faceStore = MockFaceEnrollmentStore(
            statuses: [
                "student-1": .enrolled(photoCount: 4, updatedAt: .now),
                "user-2": .needsSetup
            ]
        )

        let model = ClassRosterModel(
            session: .previewTeacher,
            classesService: classesService,
            faceEnrollmentStore: faceStore
        )

        let selectedClass = MBClass(
            id: "class-1",
            displayName: "Red Room",
            iconName: "",
            isLocked: false,
            isMember: true
        )

        await model.loadIfNeeded(for: selectedClass, classContext: .schoolClass(id: "class-1"))
        let students = model.students

        #expect(students.count == 2)
        #expect(students.allSatisfy { $0.studentKey.starts(with: "student") || $0.studentKey == "user-2" })
        #expect(students[0].studentKey == "student-1")
        #expect(students[0].isFaceEnrolled == true)
        #expect(students[1].isFaceEnrolled == false)
    }

    @Test("All-classes context clears class roster state")
    func clearsStudentsWhenContextIsAllClasses() async throws {
        let classesService = MockClassRosterClassesService(
            membersByClass: [
                "class-1": [
                    MBMember(
                        id: "member-1",
                        user: MBMemberUser(id: "user-1", fullName: "Alice Zephyr"),
                        studentID: "student-1"
                    )
                ]
            ]
        )

        let model = ClassRosterModel(
            session: .previewTeacher,
            classesService: classesService,
            faceEnrollmentStore: MockFaceEnrollmentStore(statuses: [:])
        )

        let selectedClass = MBClass(
            id: "class-1",
            displayName: "Red Room",
            iconName: "",
            isLocked: false,
            isMember: true
        )

        await model.loadIfNeeded(for: selectedClass, classContext: .schoolClass(id: "class-1"))
        #expect(model.students.count == 1)

        await model.loadIfNeeded(for: selectedClass, classContext: .allClasses)
        #expect(model.students.isEmpty)
        #expect(model.errorMessage == nil)
        #expect(model.localStatusErrorMessage == nil)
    }

    @Test("Face enrollment lookup failure marks students as setup-needed")
    func treatsUnavailableFaceStoreAsNeedsSetup() async throws {
        let classesService = MockClassRosterClassesService(
            membersByClass: [
                "class-1": [
                    MBMember(
                        id: "member-1",
                        user: MBMemberUser(id: "user-1", fullName: "Alice Zephyr"),
                        studentID: "student-1"
                    )
                ]
            ]
        )
        let faceStore = FailingFaceEnrollmentStore(error: NSError(domain: "Test", code: 1))

        let model = ClassRosterModel(
            session: .previewTeacher,
            classesService: classesService,
            faceEnrollmentStore: faceStore
        )

        await model.loadIfNeeded(
            for: MBClass(
                id: "class-1",
                displayName: "Red Room",
                iconName: "",
                isLocked: false,
                isMember: true
            ),
            classContext: .schoolClass(id: "class-1")
        )

        #expect(model.students.count == 1)
        #expect(model.students.first?.needsFaceEnrollment == true)
        #expect(model.localStatusErrorMessage != nil)
    }
}

private struct MockClassRosterClassesService: ClassesService {
    var membersByClass: [String: [MBMember]]

    func loadClasses(for session: AuthSession, childContext: ChildContext) async throws -> [MBClass] {
        []
    }

    func loadClassTasks(
        for session: AuthSession,
        childContext: ChildContext,
        classID: String,
        query: [String: String]
    ) async throws -> [MBAPI.MBClassTask] {
        []
    }

    func loadClassUnits(
        for session: AuthSession,
        childContext: ChildContext,
        classID: String
    ) async throws -> [MBAPI.MBClassUnit] {
        []
    }

    func loadClassStudents(for session: AuthSession, classID: String) async throws -> [MBMember] {
        membersByClass[classID] ?? []
    }
}

private struct MockFaceEnrollmentStore: FaceEnrollmentStore {
    var statuses: [String: FaceEnrollmentStatus]

    func statuses(for studentKeys: [String]) async throws -> [String: FaceEnrollmentStatus] {
        Dictionary(uniqueKeysWithValues: studentKeys.map { studentKey in
            (studentKey, statuses[studentKey] ?? .needsSetup)
        })
    }

    func status(for studentKey: String) async throws -> FaceEnrollmentStatus {
        statuses[studentKey] ?? .needsSetup
    }

    func deleteEnrollment(for studentKey: String) async throws {
    }

    func upsertEnrollment(
        for studentKey: String,
        displayName: String,
        embeddings: Data,
        embeddingCount: Int,
        vectorLength: Int,
        elementType: Int,
        modelIdentifier: String
    ) async throws {
    }
}

private struct FailingFaceEnrollmentStore: FaceEnrollmentStore {
    let error: Error

    func statuses(for studentKeys: [String]) async throws -> [String: FaceEnrollmentStatus] {
        throw error
    }

    func status(for studentKey: String) async throws -> FaceEnrollmentStatus {
        throw error
    }

    func deleteEnrollment(for studentKey: String) async throws {
    }

    func upsertEnrollment(
        for studentKey: String,
        displayName: String,
        embeddings: Data,
        embeddingCount: Int,
        vectorLength: Int,
        elementType: Int,
        modelIdentifier: String
    ) async throws {
    }
}
