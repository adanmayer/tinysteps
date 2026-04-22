import SwiftUI
import MBAPI

struct PortfolioTimelineView: View {
    @State private var model: PortfolioTimelineModel
    @State private var selectedClassID: String?
    @State private var classScopes: [PortfolioClassScope]
    @State private var loadedClassScopesIdentity: String?

    private let session: AuthSession
    private let role: PortfolioTimelineRole
    private let childContext: ChildContext
    private let selectedScopeTitle: String
    private let canShowScopeSwitcher: Bool
    private let availableChildren: [MBChild]
    private let portfolioService: PortfolioService
    private let classesService: ClassesService
    private let usesExternalClassSwitcher: Bool
    private let onShowScopeSwitcher: () -> Void

    init(
        session: AuthSession,
        classContext: ClassContext,
        selectedClass: MBClass?,
        selectedScopeTitle: String,
        selectedScopeSubtitle: String,
        canShowScopeSwitcher: Bool,
        portfolioService: PortfolioService,
        classesService: ClassesService,
        onShowScopeSwitcher: @escaping () -> Void
    ) {
        let classID = classContext.apiClassID
        let title = selectedScopeTitle.isEmpty ? selectedClass?.displayName ?? "All Classes" : selectedScopeTitle

        self.session = session
        self.role = .teacherStream
        self.childContext = .allChildren
        self.selectedScopeTitle = selectedScopeTitle
        self.canShowScopeSwitcher = canShowScopeSwitcher
        self.availableChildren = []
        self.portfolioService = portfolioService
        self.classesService = classesService
        self.usesExternalClassSwitcher = true
        self.onShowScopeSwitcher = onShowScopeSwitcher
        _selectedClassID = State(initialValue: classID)
        _classScopes = State(
            initialValue: [
                PortfolioClassScope(
                    classID: classID,
                    title: title,
                    subtitle: selectedScopeSubtitle.isEmpty ? nil : selectedScopeSubtitle
                )
            ]
        )
        _model = State(
            initialValue: PortfolioTimelineModel(
                session: session,
                role: .teacherStream,
                portfolioService: portfolioService,
                classesService: classesService
            )
        )
    }

    init(
        session: AuthSession,
        childContext: ChildContext,
        selectedScopeTitle: String,
        selectedScopeSubtitle: String,
        canShowScopeSwitcher: Bool,
        availableChildren: [MBChild],
        portfolioService: PortfolioService,
        classesService: ClassesService,
        onShowScopeSwitcher: @escaping () -> Void
    ) {
        self.session = session
        self.role = .parentJournal
        self.childContext = childContext
        self.selectedScopeTitle = selectedScopeTitle
        self.canShowScopeSwitcher = canShowScopeSwitcher
        self.availableChildren = availableChildren
        self.portfolioService = portfolioService
        self.classesService = classesService
        self.usesExternalClassSwitcher = false
        self.onShowScopeSwitcher = onShowScopeSwitcher
        _selectedClassID = State(initialValue: nil)
        _classScopes = State(
            initialValue: [
                PortfolioClassScope(
                    classID: nil,
                    title: "All classes",
                    subtitle: selectedScopeSubtitle.isEmpty ? nil : selectedScopeSubtitle
                )
            ]
        )
        _model = State(
            initialValue: PortfolioTimelineModel(
                session: session,
                role: .parentJournal,
                portfolioService: portfolioService,
                classesService: classesService
            )
        )
    }

    var body: some View {
        ZStack {
            Color(hex: "#FBF6EE")
                .ignoresSafeArea()

            timelineContent
        }
        .task(id: reloadIdentity) {
            await loadLocalClassScopesIfNeeded()
            await model.reload(
                classID: selectedClassID,
                childContext: childContext,
                availableChildren: availableChildren
            )
        }
    }

    private var timelineContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            titleSection
            rangeFilter
            studentFilterStrip

            if let errorMessage = model.errorMessage {
                messageBanner(errorMessage)
            }

            if model.isLoading {
                loadingView
            } else if model.filteredEntries.isEmpty {
                emptyStateView
            } else {
                entryFeed
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                classSelector

                Spacer()

                countBadge
            }

            if role == .parentJournal, canShowScopeSwitcher {
                Button(action: onShowScopeSwitcher) {
                    classSelectorLabel(title: childPickerTitle, showsChevron: canShowScopeSwitcher)
                }
                .buttonStyle(.plain)
                .disabled(!canShowScopeSwitcher)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var countBadge: some View {
        Text(model.countText)
            .font(.footnote.weight(.medium))
            .foregroundStyle(Color(hex: "#6B8659"))
            .padding(.horizontal, 14)
            .frame(height: 28)
            .background(Color(hex: "#8DA67A").opacity(0.14))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private var classSelector: some View {
        if usesExternalClassSwitcher {
            Button(action: onShowScopeSwitcher) {
                classSelectorLabel(title: scopePickerTitle, showsChevron: canShowScopeSwitcher)
            }
            .buttonStyle(.plain)
            .disabled(!canShowScopeSwitcher)
        } else if classScopes.count > 1 {
            Menu {
                ForEach(classScopes) { scope in
                    Button {
                        selectedClassID = scope.classID
                    } label: {
                        Label(
                            scope.title,
                            systemImage: scope.classID == selectedClassID ? "checkmark" : "circle"
                        )
                    }
                }
            } label: {
                classSelectorLabel(title: scopePickerTitle, showsChevron: true)
            }
            .buttonStyle(.plain)
        } else {
            classSelectorLabel(title: scopePickerTitle, showsChevron: false)
        }
    }

    private func classSelectorLabel(title: String, showsChevron: Bool) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(hex: "#3A342E"))
                .lineLimit(1)
                .minimumScaleFactor(0.76)

            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hex: "#6E6456"))
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 44)
        .background(Color(hex: "#FFFDF8"))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
        .overlay(
            Capsule()
                .stroke(Color(hex: "#E6D8C2"), lineWidth: 0.5)
        )
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.titleText)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color(hex: "#3A342E"))
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text(model.subtitleText)
                .font(.footnote)
                .foregroundStyle(Color(hex: "#6E6456"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    private var rangeFilter: some View {
        HStack(spacing: 4) {
            ForEach(PortfolioRangeFilter.allCases) { range in
                Button {
                    model.selectRange(range)
                } label: {
                    Text(range.rawValue)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(model.selectedRange == range ? Color(hex: "#6B8659") : Color(hex: "#6E6456"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            Capsule()
                                .fill(model.selectedRange == range ? Color(hex: "#FFFDF8") : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color(hex: "#F5EDE0"))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color(hex: "#E6D8C2"), lineWidth: 0.6)
        )
        .padding(.horizontal, 20)
        .padding(.top, 18)
    }

    private var studentFilterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                PortfolioStudentFilterButton(
                    title: "All",
                    initials: "All",
                    avatarURL: nil,
                    isSelected: model.selectedStudentID == nil
                ) {
                    model.selectStudent(nil)
                }

                ForEach(model.students) { student in
                    PortfolioStudentFilterButton(
                        title: student.displayName,
                        initials: student.initials,
                        avatarURL: student.avatarURL,
                        isSelected: model.selectedStudentID == student.id
                    ) {
                        model.selectStudent(student.id)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private var entryFeed: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(model.filteredEntries) { entry in
                    PortfolioEntryCard(entry: entry)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 28)
        }
        .refreshable {
            await model.reload(
                classID: selectedClassID,
                childContext: childContext,
                availableChildren: availableChildren
            )
        }
    }

    private var loadingView: some View {
        ProgressView("Loading stream...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            model.emptyTitle,
            systemImage: "rectangle.stack",
            description: Text(model.emptyDescription)
        )
        .foregroundStyle(Color(hex: "#6E6456"))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func messageBanner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote.weight(.medium))
            .foregroundStyle(Color(hex: "#C97A6E"))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "#FFFDF8").opacity(0.86))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 12)
    }

    private var scopePickerTitle: String {
        if usesExternalClassSwitcher {
            return selectedScopeTitle.isEmpty ? "All Classes" : selectedScopeTitle
        }

        return classScopes.first { $0.classID == selectedClassID }?.title ?? "All classes"
    }

    private var childPickerTitle: String {
        selectedScopeTitle.isEmpty ? "All Children" : selectedScopeTitle
    }

    private var childContextIdentity: String {
        switch childContext {
        case .allChildren:
            return "all-children"
        case .child(let id):
            return id
        }
    }

    private var reloadIdentity: String {
        "\(role)-\(selectedClassID ?? "all-classes")-\(childContextIdentity)"
    }

    private func loadLocalClassScopesIfNeeded() async {
        guard usesExternalClassSwitcher == false else {
            return
        }

        guard loadedClassScopesIdentity != childContextIdentity else {
            return
        }

        loadedClassScopesIdentity = childContextIdentity
        selectedClassID = nil

        do {
            let classes = try await classesService.loadClasses(for: session, childContext: childContext)
            var scopes = [
                PortfolioClassScope(
                    classID: nil,
                    title: "All classes",
                    subtitle: classes.isEmpty ? nil : "\(classes.count) classes"
                )
            ]
            scopes.append(
                contentsOf: classes.map { schoolClass in
                    PortfolioClassScope(
                        classID: schoolClass.id,
                        title: schoolClass.displayName,
                        subtitle: schoolClass.program?.name
                    )
                }
            )
            classScopes = scopes
        } catch {
            classScopes = [
                PortfolioClassScope(classID: nil, title: "All classes", subtitle: nil)
            ]
        }
    }
}

private struct PortfolioStudentFilterButton: View {
    let title: String
    let initials: String
    let avatarURL: URL?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                avatar
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isSelected ? Color(hex: "#6B8659") : Color(hex: "#6E6456"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(width: 58)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title == "All" ? "Show all students" : "Show moments for \(title)")
    }

    @ViewBuilder
    private var avatar: some View {
        if let avatarURL {
            AsyncImage(url: avatarURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .empty, .failure:
                    initialsView
                @unknown default:
                    initialsView
                }
            }
            .frame(width: 42, height: 42)
            .clipShape(Circle())
            .overlay(avatarBorder)
        } else {
            initialsView
                .frame(width: 42, height: 42)
                .overlay(avatarBorder)
        }
    }

    private var initialsView: some View {
        Text(initials)
            .font(.caption.weight(.bold))
            .foregroundStyle(Color(hex: "#3A342E"))
            .frame(width: 42, height: 42)
            .background(isSelected ? Color(hex: "#8DA67A").opacity(0.18) : Color(hex: "#FFFDF8"))
            .clipShape(Circle())
    }

    private var avatarBorder: some View {
        Circle()
            .stroke(isSelected ? Color(hex: "#6B8659") : Color(hex: "#E6D8C2"), lineWidth: isSelected ? 2 : 1)
    }
}

private struct PortfolioEntryCard: View {
    let entry: PortfolioEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            mediaView
            bodyText
            tagGrid
            avatarRow
        }
        .padding(18)
        .background(Color(hex: "#FFFDF8"))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color(hex: "#F1E7D8"), lineWidth: 0.6)
        )
        .shadow(color: .black.opacity(0.05), radius: 16, x: 0, y: 8)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: entry.kind.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: "#6B8659"))
                .frame(width: 28, height: 28)
                .background(Color(hex: "#F5EDE0"))
                .clipShape(Circle())

            Text(headerText)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color(hex: "#6E6456"))
                .lineLimit(1)
                .minimumScaleFactor(0.76)

            Spacer()
        }
    }

    @ViewBuilder
    private var mediaView: some View {
        switch entry.media {
        case .photo(let url, let altText):
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .empty:
                    ZStack {
                        Color(hex: "#F5EDE0")
                        ProgressView()
                    }
                case .failure:
                    mediaFallback(systemImage: "photo", text: altText ?? "Photo")
                @unknown default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        case .video:
            mediaFallback(systemImage: "play.rectangle.fill", text: "Video")
        case .file(let title, let subtitle, _):
            mediaFallback(systemImage: "doc.fill", text: [title, subtitle].compactMap { $0 }.joined(separator: " - "))
        case .website(let url, let title, _):
            mediaFallback(systemImage: "link", text: title ?? url.host ?? url.absoluteString)
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private var bodyText: some View {
        if let bodyText = entry.bodyText {
            Text(bodyText)
                .font(.body)
                .lineSpacing(7)
                .foregroundStyle(Color(hex: "#3A342E"))
                .lineLimit(5)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var tagGrid: some View {
        if entry.tags.isEmpty == false {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 110), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(entry.tags.prefix(6), id: \.self) { tag in
                    Text(tag)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color(hex: "#6B8659"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .background(Color(hex: "#8DA67A").opacity(0.14))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color(hex: "#8DA67A"), lineWidth: 1)
                        )
                }
            }
        }
    }

    @ViewBuilder
    private var avatarRow: some View {
        if entry.attributedStudents.isEmpty {
            Label("No student attribution", systemImage: "person.crop.circle.badge.questionmark")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color(hex: "#A89E8F"))
        } else {
            Divider()
                .background(Color(hex: "#E6D8C2").opacity(0.7))
            HStack(spacing: -8) {
                ForEach(entry.attributedStudents.prefix(5)) { student in
                    PortfolioMiniAvatar(student: student)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func mediaFallback(systemImage: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(hex: "#6B8659"))
                .frame(width: 36, height: 36)
                .background(Color(hex: "#8DA67A").opacity(0.14))
                .clipShape(Circle())

            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(hex: "#3A342E"))
                .lineLimit(2)
                .minimumScaleFactor(0.82)

            Spacer()
        }
        .padding(14)
        .background(Color(hex: "#F5EDE0"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var headerText: String {
        let subject = entry.attributedStudents.first?.displayName ?? entry.title ?? entry.kind.rawValue
        guard let createdAt = entry.createdAt else {
            return subject
        }

        return "\(subject) - \(Self.timeFormatter.string(from: createdAt))"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}

private struct PortfolioMiniAvatar: View {
    let student: PortfolioStudent

    var body: some View {
        Group {
            if let avatarURL = student.avatarURL {
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty, .failure:
                        initialsView
                    @unknown default:
                        initialsView
                    }
                }
            } else {
                initialsView
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color(hex: "#8DA67A"), lineWidth: 1)
        )
        .accessibilityLabel(student.displayName)
    }

    private var initialsView: some View {
        Text(student.initials)
            .font(.caption.weight(.bold))
            .foregroundStyle(Color(hex: "#3A342E"))
            .frame(width: 32, height: 32)
            .background(Color(hex: "#F5EDE0"))
    }
}
