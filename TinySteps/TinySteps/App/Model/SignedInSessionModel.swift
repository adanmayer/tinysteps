import Foundation
import MBAPI
import Observation

@Observable
@MainActor
final class SignedInSessionModel {
    private(set) var availableChildren: [MBChild] = []
    private(set) var availableClasses: [MBClass] = []
    private(set) var selectedChildContext: ChildContext = .allChildren
    private(set) var selectedClassContext: ClassContext = .allClasses
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var resolvedRole: MBAPIRole?

    let session: AuthSession

    private let authController: AuthController
    private let childrenService: ChildrenService
    private let classesService: ClassesService
    private let childSelectionStore: ChildSelectionStore
    private let classSelectionStore: ClassSelectionStore
    private var hasLoaded = false

    init(
        session: AuthSession,
        authController: AuthController,
        childrenService: ChildrenService,
        classesService: ClassesService,
        childSelectionStore: ChildSelectionStore,
        classSelectionStore: ClassSelectionStore
    ) {
        self.session = session
        self.authController = authController
        self.childrenService = childrenService
        self.classesService = classesService
        self.childSelectionStore = childSelectionStore
        self.classSelectionStore = classSelectionStore
        self.resolvedRole = session.apiRole
    }

    // MARK: - Parent helpers

    var selectedChild: MBChild? {
        guard case .child(let id) = selectedChildContext else {
            return nil
        }

        return availableChildren.first { $0.id == id }
    }

    var childSwitcherOptions: [ChildSwitcherOption] {
        var options = [ChildSwitcherOption]()

        if availableChildren.count > 1 {
            options.append(
                ChildSwitcherOption(
                    context: .allChildren,
                    title: "All Children",
                    subtitle: "Combined parent view",
                    isSelected: selectedChildContext == .allChildren
                )
            )
        }

        options.append(
            contentsOf: availableChildren.map { child in
                ChildSwitcherOption(
                    context: .child(id: child.id),
                    title: child.displayName,
                    subtitle: child.secondaryText,
                    isSelected: selectedChildContext == .child(id: child.id)
                )
            }
        )

        return options
    }

    var canShowChildSwitcher: Bool {
        !availableChildren.isEmpty
    }

    var selectedChildTitle: String {
        selectedChild?.displayName ?? "All Children"
    }

    var selectedChildSubtitle: String {
        if let selectedChild, let secondaryText = selectedChild.secondaryText {
            return secondaryText
        }

        if availableChildren.isEmpty {
            return "No children available"
        }

        return "\(availableChildren.count) children"
    }

    // MARK: - Teacher helpers

    var selectedClass: MBClass? {
        guard case .schoolClass(let id) = selectedClassContext else {
            return nil
        }

        return availableClasses.first { $0.id == id }
    }

    var classSwitcherOptions: [ClassSwitcherOption] {
        var options = [ClassSwitcherOption]()

        if availableClasses.count > 1 {
            options.append(
                ClassSwitcherOption(
                    context: .allClasses,
                    title: "All Classes",
                    subtitle: "Combined teacher view",
                    isSelected: selectedClassContext == .allClasses
                )
            )
        }

        options.append(
            contentsOf: availableClasses.map { schoolClass in
                ClassSwitcherOption(
                    context: .schoolClass(id: schoolClass.id),
                    title: schoolClass.displayName,
                    subtitle: schoolClass.program?.name,
                    isSelected: selectedClassContext == .schoolClass(id: schoolClass.id)
                )
            }
        )

        return options
    }

    var canShowClassSwitcher: Bool {
        !availableClasses.isEmpty
    }

    var selectedClassTitle: String {
        selectedClass?.displayName ?? "All Classes"
    }

    var selectedClassSubtitle: String {
        if let program = selectedClass?.program?.name {
            return program
        }

        if availableClasses.isEmpty {
            return "No classes available"
        }

        return "\(availableClasses.count) classes"
    }

    // MARK: - Loading

    func loadIfNeeded() async {
        guard !hasLoaded else {
            return
        }

        hasLoaded = true
        await reload()
    }

    func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        if let role = session.apiRole ?? resolvedRole {
            await loadData(for: role)
            return
        }

        // Probe to detect role: try parent first, then teacher. Each probe
        // also loads the list it queried, so a successful probe doubles as
        // the initial data fetch.
        if await probeAsParent() { return }
        if await probeAsTeacher() { return }

        errorMessage = "Unable to determine account type."
    }

    private func loadData(for role: MBAPIRole) async {
        do {
            switch role {
            case .parent:
                try await loadChildren()
            case .teacher, .student:
                try await loadClasses()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func probeAsParent() async -> Bool {
        authController.recordIdentifiedRole(.parent)
        do {
            let children = try await childrenService.loadChildren(for: session)
            availableChildren = children
            selectedChildContext = resolvedChildSelection(for: children)
            persistChildSelection()
            resolvedRole = .parent
            return true
        } catch {
            return false
        }
    }

    private func probeAsTeacher() async -> Bool {
        authController.recordIdentifiedRole(.teacher)
        do {
            let classes = try await classesService.loadClasses(for: session, childContext: .allChildren)
            availableClasses = classes
            selectedClassContext = resolvedClassSelection(for: classes)
            persistClassSelection()
            resolvedRole = .teacher
            return true
        } catch {
            return false
        }
    }

    private func loadChildren() async throws {
        let children = try await childrenService.loadChildren(for: session)
        availableChildren = children
        selectedChildContext = resolvedChildSelection(for: children)
        persistChildSelection()
    }

    private func loadClasses() async throws {
        let classes = try await classesService.loadClasses(for: session, childContext: .allChildren)
        availableClasses = classes
        selectedClassContext = resolvedClassSelection(for: classes)
        persistClassSelection()
    }

    func selectChild(_ context: ChildContext) {
        switch context {
        case .allChildren:
            guard availableChildren.count > 1 else {
                return
            }
        case .child(let id):
            guard availableChildren.contains(where: { $0.id == id }) else {
                return
            }
        }

        selectedChildContext = context
        persistChildSelection()
    }

    func selectClass(_ context: ClassContext) {
        switch context {
        case .allClasses:
            guard availableClasses.count > 1 else {
                return
            }
        case .schoolClass(let id):
            guard availableClasses.contains(where: { $0.id == id }) else {
                return
            }
        }

        selectedClassContext = context
        persistClassSelection()
    }

    // MARK: - Persistence

    private func resolvedChildSelection(for children: [MBChild]) -> ChildContext {
        if children.count == 1, let onlyChild = children.first {
            return .child(id: onlyChild.id)
        }

        guard let storedSelection = childSelectionStore.loadSelection(for: session) else {
            return .allChildren
        }

        switch storedSelection {
        case .allChildren:
            return .allChildren
        case .child(let id):
            return children.contains(where: { $0.id == id }) ? .child(id: id) : .allChildren
        }
    }

    private func persistChildSelection() {
        childSelectionStore.saveSelection(selectedChildContext, for: session)
    }

    private func resolvedClassSelection(for classes: [MBClass]) -> ClassContext {
        if classes.count == 1, let onlyClass = classes.first {
            return .schoolClass(id: onlyClass.id)
        }

        guard let storedSelection = classSelectionStore.loadSelection(for: session) else {
            return .allClasses
        }

        switch storedSelection {
        case .allClasses:
            return .allClasses
        case .schoolClass(let id):
            return classes.contains(where: { $0.id == id }) ? .schoolClass(id: id) : .allClasses
        }
    }

    private func persistClassSelection() {
        classSelectionStore.saveSelection(selectedClassContext, for: session)
    }
}
