import Foundation
import MBAPI
import Observation

@Observable
@MainActor
final class PortfolioTimelineModel {
    private(set) var entries: [PortfolioEntry] = []
    private(set) var students: [PortfolioStudent] = []
    private(set) var isLoading = false
    private(set) var isRefreshing = false
    private(set) var errorMessage: String?
    private(set) var hasLoaded = false
    var selectedRange: PortfolioRangeFilter
    var selectedStudentID: PortfolioStudent.ID?

    private let session: AuthSession
    private let role: PortfolioTimelineRole
    private let portfolioService: PortfolioService
    private let classesService: ClassesService
    private let calendar: Calendar
    private let now: @MainActor () -> Date

    init(
        session: AuthSession,
        role: PortfolioTimelineRole,
        portfolioService: PortfolioService,
        classesService: ClassesService,
        calendar: Calendar = .current,
        now: @escaping @MainActor () -> Date = Date.init
    ) {
        self.session = session
        self.role = role
        self.portfolioService = portfolioService
        self.classesService = classesService
        self.calendar = calendar
        self.now = now
        selectedRange = role.defaultRange
    }

    var rangeFilteredEntries: [PortfolioEntry] {
        switch selectedRange {
        case .all:
            return entries
        case .today:
            let today = now()
            return entries.filter { entry in
                guard let createdAt = entry.createdAt else {
                    return false
                }

                return calendar.isDate(createdAt, inSameDayAs: today)
            }
        }
    }

    var filteredEntries: [PortfolioEntry] {
        guard let selectedStudentID else {
            return rangeFilteredEntries
        }

        return rangeFilteredEntries.filter { $0.isAttributed(to: selectedStudentID) }
    }

    var selectedStudent: PortfolioStudent? {
        guard let selectedStudentID else {
            return nil
        }

        return students.first { $0.id == selectedStudentID }
    }

    var countText: String {
        let count = filteredEntries.count
        switch selectedRange {
        case .today:
            return "\(count) today"
        case .all:
            return "\(count) \(count == 1 ? "moment" : "moments")"
        }
    }

    var titleText: String {
        switch role {
        case .teacherStream:
            return "Stream"
        case .parentJournal:
            if students.count == 1, let student = students.first {
                return "\(student.displayName)'s journal"
            }
            return "Journal"
        }
    }

    var subtitleText: String {
        switch selectedRange {
        case .today:
            return formattedToday()
        case .all:
            switch role {
            case .teacherStream:
                return "All moments"
            case .parentJournal:
                return "All shared moments"
            }
        }
    }

    var emptyTitle: String {
        if let selectedStudent {
            return "No moments for \(selectedStudent.displayName) yet."
        }

        switch (role, selectedRange) {
        case (.teacherStream, .today):
            return "Nothing captured yet today."
        case (.teacherStream, .all):
            return "No moments in this stream yet."
        case (.parentJournal, _):
            return "The journey starts here."
        }
    }

    var emptyDescription: String {
        if selectedStudentID != nil {
            if rangeFilteredEntries.isEmpty == false {
                return "These entries do not include explicit student attribution yet, so they stay under All."
            }
            return "Try All to see the rest of the stream."
        }

        switch (role, selectedRange) {
        case (.teacherStream, .today):
            return "Press and hold to record what you saw."
        case (.teacherStream, .all):
            return "Published class moments will appear here."
        case (.parentJournal, _):
            return "Their teacher will share the first moment soon."
        }
    }

    func selectRange(_ range: PortfolioRangeFilter) {
        selectedRange = range
    }

    func selectStudent(_ studentID: PortfolioStudent.ID?) {
        selectedStudentID = studentID
    }

    func loadIfNeeded(
        classID: String?,
        childContext: ChildContext,
        availableChildren: [MBChild]
    ) async {
        guard hasLoaded == false else {
            return
        }

        await reload(
            classID: classID,
            childContext: childContext,
            availableChildren: availableChildren
        )
    }

    func reload(
        classID: String?,
        childContext: ChildContext,
        availableChildren: [MBChild]
    ) async {
        let isInitialLoad = hasLoaded == false
        if isInitialLoad {
            isLoading = true
        } else {
            isRefreshing = true
        }
        errorMessage = nil
        defer {
            isLoading = false
            isRefreshing = false
            hasLoaded = true
        }

        do {
            async let loadedStudents = loadStudents(
                classID: classID,
                childContext: childContext,
                availableChildren: availableChildren
            )
            async let loadedItems = portfolioService.loadPortfolioTimeline(
                for: session,
                childContext: childContext,
                classID: classID,
                query: [:]
            )

            let resolvedStudents = try await loadedStudents
            let resolvedItems = try await loadedItems

            entries = PortfolioEntryNormalizer.normalize(resolvedItems)
            students = resolvedStudents.isEmpty && role == .teacherStream && classID == nil
                ? studentsFromEntries(entries)
                : resolvedStudents
            if let selectedStudentID, students.contains(where: { $0.id == selectedStudentID }) == false {
                self.selectedStudentID = nil
            }
        } catch {
            if isInitialLoad {
                entries = []
                students = childScopedStudents(from: availableChildren, childContext: childContext)
            }
            errorMessage = "The stream is unavailable right now."
        }
    }

    private func loadStudents(
        classID: String?,
        childContext: ChildContext,
        availableChildren: [MBChild]
    ) async throws -> [PortfolioStudent] {
        switch role {
        case .teacherStream:
            guard let classID else {
                return []
            }

            let members = try await classesService.loadClassStudents(for: session, classID: classID)
            return members
                .map(PortfolioStudent.init)
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        case .parentJournal:
            return childScopedStudents(from: availableChildren, childContext: childContext)
        }
    }

    private func childScopedStudents(
        from availableChildren: [MBChild],
        childContext: ChildContext
    ) -> [PortfolioStudent] {
        let children: [MBChild]
        switch childContext {
        case .allChildren:
            children = availableChildren
        case .child(let id):
            children = availableChildren.filter { $0.id == id }
        }

        return children
            .map(PortfolioStudent.init)
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private func studentsFromEntries(_ entries: [PortfolioEntry]) -> [PortfolioStudent] {
        var seen = Set<PortfolioStudent.ID>()
        var students: [PortfolioStudent] = []
        for entry in entries {
            for student in entry.attributedStudents where seen.insert(student.id).inserted {
                students.append(student)
            }
        }

        return students.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    private func formattedToday() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: now())
    }
}

private extension PortfolioStudent {
    init(member: MBMember) {
        self.init(
            id: member.rosterStudentKey,
            displayName: member.displayName,
            avatarURL: member.user.avatarURL
        )
    }

    init(child: MBChild) {
        self.init(
            id: child.id,
            displayName: child.displayName,
            avatarURL: child.avatarURL
        )
    }
}
