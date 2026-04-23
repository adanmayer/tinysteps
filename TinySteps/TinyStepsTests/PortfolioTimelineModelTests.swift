import Foundation
import MBAPI
import Testing
@testable import TinySteps

@MainActor
struct PortfolioTimelineModelTests {
    @Test("Normalizer maps note body and de-duplicates tags")
    func normalizerMapsNoteBodyAndTags() {
        let item = Self.timelineItem(
            id: "moment-1",
            createdAt: Date(timeIntervalSince1970: 1_776_800_000),
            title: nil,
            body: "Amara counted the red cups carefully.",
            labels: ["PYP", "Thinking"],
            logableLabels: ["thinking", "Connection"]
        )

        let entry = PortfolioEntryNormalizer.normalize(item)

        #expect(entry.kind == .note)
        #expect(entry.bodyText == "Amara counted the red cups carefully.")
        #expect(entry.tags == ["PYP", "Thinking", "Connection"])
        #expect(entry.attributedStudents.isEmpty)
    }

    @Test("Normalizer maps explicit attributed students decoded from timeline JSON")
    func normalizerMapsDecodedAttributedStudents() throws {
        let data = """
        {
          "id": "moment-children",
          "logable_type": "note",
          "status": "published",
          "created_at": "2026-04-22T07:30:00Z",
          "logable": {
            "id": "moment-children-log",
            "kind": "note",
            "body": "Amara shared her tower with Leo.",
            "children": [
              {
                "child_id": "child-1",
                "display_name": "Amara Quinn",
                "avatar_url": "https://example.test/amara.png"
              }
            ]
          }
        }
        """.data(using: .utf8)!

        let item = try JSONDecoder().decode(MBAPI.Portfolio.TimelineItem.self, from: data)
        let entry = PortfolioEntryNormalizer.normalize(item)

        #expect(entry.attributedStudents.map(\.id) == ["child-1"])
        #expect(entry.attributedStudents.map(\.displayName) == ["Amara Quinn"])
        #expect(entry.attributedStudents.first?.avatarURL?.absoluteString == "https://example.test/amara.png")
    }

    @Test("Range filter shows today by default and All when selected")
    func rangeFilterShowsTodayAndAll() async throws {
        let today = Self.timelineItem(
            id: "today",
            createdAt: Date(),
            title: nil,
            body: "Today moment."
        )
        let older = Self.timelineItem(
            id: "older",
            createdAt: Date(timeIntervalSinceNow: -172_800),
            title: nil,
            body: "Older moment."
        )
        let model = PortfolioTimelineModel(
            session: .previewTeacher,
            role: .teacherStream,
            portfolioService: FakePortfolioService(items: [older, today]),
            classesService: FakePortfolioClassesService()
        )

        await model.loadIfNeeded(
            classID: "blue-room",
            childContext: .allChildren,
            availableChildren: []
        )

        #expect(model.filteredEntries.map(\.id) == ["today"])

        model.selectRange(.all)

        #expect(model.filteredEntries.map(\.id) == ["today", "older"])
    }

    @Test("Selected student filtering does not infer attribution from text")
    func selectedStudentFilteringRequiresExplicitAttribution() async throws {
        let child = MBChild(
            id: "child-1",
            displayName: "Amara Quinn",
            initials: "AQ"
        )
        let model = PortfolioTimelineModel(
            session: .preview,
            role: .parentJournal,
            portfolioService: FakePortfolioService(
                items: [
                    Self.timelineItem(
                        id: "moment-1",
                        createdAt: Date(),
                        title: nil,
                        body: "Amara counted the red cups carefully."
                    )
                ]
            ),
            classesService: FakePortfolioClassesService()
        )

        await model.loadIfNeeded(
            classID: nil,
            childContext: .allChildren,
            availableChildren: [child]
        )

        #expect(model.filteredEntries.count == 1)

        model.selectStudent("child-1")

        #expect(model.filteredEntries.isEmpty)
        #expect(model.emptyDescription.contains("explicit student attribution"))
    }

    @Test("Selected student filter treats empty assigned user IDs as all students")
    func selectedStudentFilteringTreatsEmptyAssignedUserIDsAsAllStudents() async throws {
        let data = """
        {
          "id": "moment-all-students",
          "logable_type": "note",
          "status": "published",
          "created_at": "2026-04-22T07:30:00Z",
          "assigned_user_ids": [],
          "logable": {
            "id": "moment-all-students-log",
            "kind": "note",
            "body": "Shared with the whole class."
          }
        }
        """.data(using: .utf8)!

        let item = try JSONDecoder().decode(MBAPI.Portfolio.TimelineItem.self, from: data)
        let entry = PortfolioEntryNormalizer.normalize(item)
        let model = PortfolioTimelineModel(
            session: .previewTeacher,
            role: .teacherStream,
            portfolioService: FakePortfolioService(items: [item]),
            classesService: FakePortfolioClassesService()
        )

        #expect(item.isAssignedToAllStudents)
        #expect(entry.isAssignedToAllStudents)

        await model.loadIfNeeded(
            classID: "blue-room",
            childContext: .allChildren,
            availableChildren: []
        )

        model.selectRange(.all)
        model.selectStudent("child-1")

        #expect(model.filteredEntries.map(\.id) == ["moment-all-students"])
    }

    @Test("Parent student filters follow selected child context")
    func parentStudentFiltersFollowSelectedChildContext() async throws {
        let children = [
            MBChild(id: "child-1", displayName: "Amara Quinn", initials: "AQ"),
            MBChild(id: "child-2", displayName: "Leo Chen", initials: "LC")
        ]
        let model = PortfolioTimelineModel(
            session: .preview,
            role: .parentJournal,
            portfolioService: FakePortfolioService(items: []),
            classesService: FakePortfolioClassesService()
        )

        await model.loadIfNeeded(
            classID: nil,
            childContext: .child(id: "child-2"),
            availableChildren: children
        )

        #expect(model.students.map(\.id) == ["child-2"])
    }

    @Test("Teacher all-class stream derives student filters from explicit entry attribution")
    func teacherAllClassStreamDerivesStudentsFromEntries() async throws {
        let item = Self.timelineItem(
            id: "moment-1",
            createdAt: Date(),
            title: nil,
            body: "Amara counted the red cups carefully.",
            attributedStudents: [
                .init(id: "child-1", displayName: "Amara Quinn")
            ]
        )
        let model = PortfolioTimelineModel(
            session: .previewTeacher,
            role: .teacherStream,
            portfolioService: FakePortfolioService(items: [item]),
            classesService: FakePortfolioClassesService()
        )

        await model.loadIfNeeded(
            classID: nil,
            childContext: .allChildren,
            availableChildren: []
        )

        #expect(model.students.map(\.id) == ["child-1"])

        model.selectStudent("child-1")

        #expect(model.filteredEntries.map(\.id) == ["moment-1"])
    }

    private static func timelineItem(
        id: String,
        createdAt: Date,
        title: String?,
        body: String,
        labels: [String] = [],
        logableLabels: [String] = [],
        attributedStudents: [MBAPI.Portfolio.TimelineItem.AttributedStudent] = []
    ) -> MBAPI.Portfolio.TimelineItem {
        MBAPI.Portfolio.TimelineItem(
            id: id,
            logableType: "note",
            status: "published",
            createdAt: ISO8601DateFormatter().string(from: createdAt),
            logable: .init(
                id: "\(id)-log",
                title: title,
                kind: "note",
                body: body,
                labels: logableLabels
            ),
            labels: labels,
            attributedStudents: attributedStudents
        )
    }
}

private struct FakePortfolioService: PortfolioService {
    let items: [MBAPI.Portfolio.TimelineItem]

    func loadPortfolioTimeline(
        for session: AuthSession,
        childContext: ChildContext,
        classID: String?,
        query: [String: String]
    ) async throws -> [MBAPI.Portfolio.TimelineItem] {
        items
    }

    func createClassNote(
        for session: AuthSession,
        classID: String,
        payload: PortfolioNoteCreatePayload
    ) async throws -> MBAPI.Portfolio.ResourceCreateResponse {
        MBAPI.Portfolio.ResourceCreateResponse(id: "created-note")
    }

    func uploadPhoto(
        for session: AuthSession,
        imageData: Data,
        filename: String,
        mimeType: String
    ) async throws -> MBAPI.Portfolio.UploadedPhoto {
        MBAPI.Portfolio.UploadedPhoto(id: "uploaded-photo")
    }

    func createClassPhoto(
        for session: AuthSession,
        classID: String,
        payload: PortfolioPhotoCreatePayload
    ) async throws -> MBAPI.Portfolio.ResourceCreateResponse {
        MBAPI.Portfolio.ResourceCreateResponse(id: "created-photo")
    }

    func loadClassPortfolioSettings(
        for session: AuthSession,
        programID: String
    ) async throws -> MBAPI.Portfolio.Settings {
        MBAPI.Portfolio.Settings(id: "settings")
    }

    func uploadAudioDescription(
        for session: AuthSession,
        audioData: Data,
        filename: String,
        mimeType: String
    ) async throws -> String {
        "signed-audio-id"
    }
}

private struct FakePortfolioClassesService: ClassesService {
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
        [
            MBMember(
                id: "member-1",
                user: MBMemberUser(id: "child-1", fullName: "Amara Quinn", initials: "AQ"),
                studentID: "child-1"
            )
        ]
    }
}
