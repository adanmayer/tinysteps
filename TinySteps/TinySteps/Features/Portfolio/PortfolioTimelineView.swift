import SwiftUI
import AVFoundation
import MBAPI

struct PortfolioTimelineView: View {
    @State private var model: PortfolioTimelineModel
    @State private var selectedClassID: String?
    @State private var classScopes: [PortfolioClassScope]
    @State private var loadedClassScopesIdentity: String?
    @State private var isShowingStudentFilterSheet = false

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
            rangeFilter
            if role == .parentJournal {
                studentFilterStrip
            }

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

    @ViewBuilder
    private var header: some View {
        if role == .teacherStream {
            ClassPageTitleHeader(
                title: "Stream",
                classTitle: scopePickerTitle,
                canShowClassSwitcher: canShowScopeSwitcher,
                onShowClassSwitcher: onShowScopeSwitcher
            )
            .padding(.horizontal, 20)
            .padding(.top, 16)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    classSelector

                    Spacer()

                    countBadge
                }

                if canShowScopeSwitcher {
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
        HStack(spacing: 10) {
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
            .frame(maxWidth: .infinity)

            if role == .teacherStream {
                studentFilterButton
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, role == .teacherStream ? 4 : 0)
    }

    private var studentFilterButton: some View {
        Button {
            isShowingStudentFilterSheet = true
        } label: {
            HStack(spacing: 8) {
                selectedStudentFilterAvatar

                Text(selectedStudentFilterTitle)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(hex: "#3A342E"))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.78)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "#6E6456"))
            }
            .padding(.horizontal, 13)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color(hex: "#FFFDF8"))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
            .overlay(
                Capsule()
                    .stroke(Color(hex: "#E6D8C2"), lineWidth: 0.6)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isShowingStudentFilterSheet) {
            PortfolioStudentFilterSheet(
                students: model.students,
                selectedStudentID: model.selectedStudentID,
                onSelect: { studentID in
                    model.selectStudent(studentID)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var selectedStudentFilterAvatar: some View {
        if let student = model.selectedStudent {
            StudentAvatarView(
                name: student.displayName,
                initials: student.initials,
                avatarURL: student.avatarURL,
                cacheKey: student.id
            )
            .frame(width: 24, height: 24)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color(hex: "#E6D8C2"), lineWidth: 1)
            )
        }
    }

    private var studentFilterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                PortfolioStudentFilterButton(
                    title: "All",
                    initials: "All",
                    avatarURL: nil,
                    avatarCacheKey: "all-students",
                    isSelected: model.selectedStudentID == nil
                ) {
                    model.selectStudent(nil)
                }

                ForEach(model.students) { student in
                    PortfolioStudentFilterButton(
                        title: student.displayName,
                        initials: student.initials,
                        avatarURL: student.avatarURL,
                        avatarCacheKey: student.id,
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

    private var selectedStudentFilterTitle: String {
        guard
            let selectedStudentID = model.selectedStudentID,
            let student = model.students.first(where: { $0.id == selectedStudentID })
        else {
            return "All"
        }

        return student.displayName.isEmpty ? "Student" : student.displayName
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

private struct PortfolioStudentFilterSheet: View {
    let students: [PortfolioStudent]
    let selectedStudentID: PortfolioStudent.ID?
    let onSelect: (PortfolioStudent.ID?) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    allStudentsRow

                    ForEach(students) { student in
                        studentRow(student)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            .background(Color(hex: "#FBF6EE").ignoresSafeArea())
            .navigationTitle("Filter students")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var allStudentsRow: some View {
        Button {
            select(nil)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#F5EDE0"))
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: "#6B8659"))
                }
                .frame(width: 36, height: 36)

                Text("All")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hex: "#3A342E"))

                Spacer()

                selectionIndicator(isSelected: selectedStudentID == nil)
            }
            .padding(.horizontal, 14)
            .frame(height: 58)
            .background(rowBackground(isSelected: selectedStudentID == nil))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show all students")
    }

    private func studentRow(_ student: PortfolioStudent) -> some View {
        let isSelected = selectedStudentID == student.id

        return Button {
            select(student.id)
        } label: {
            HStack(spacing: 12) {
                StudentAvatarView(
                    name: student.displayName,
                    initials: student.initials,
                    avatarURL: student.avatarURL,
                    cacheKey: student.id
                )
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color(hex: "#E6D8C2"), lineWidth: 1)
                )

                Text(student.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hex: "#3A342E"))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                selectionIndicator(isSelected: isSelected)
            }
            .padding(.horizontal, 14)
            .frame(height: 58)
            .background(rowBackground(isSelected: isSelected))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show moments for \(student.displayName)")
    }

    private func select(_ studentID: PortfolioStudent.ID?) {
        onSelect(studentID)
        dismiss()
    }

    private func selectionIndicator(isSelected: Bool) -> some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(isSelected ? Color(hex: "#6B8659") : Color(hex: "#D4C7B6"))
    }

    private func rowBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Color(hex: "#FFFDF8"))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? Color(hex: "#6B8659") : Color(hex: "#E6D8C2"), lineWidth: isSelected ? 1.4 : 0.7)
            )
    }
}

private struct PortfolioStudentFilterButton: View {
    let title: String
    let initials: String
    let avatarURL: URL?
    let avatarCacheKey: String
    let isSelected: Bool
    let action: () -> Void
    private let avatarDimension: CGFloat = 24
    private let titleHorizontalInset: CGFloat = 6

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
                    .padding(.horizontal, titleHorizontalInset)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title == "All" ? "Show all students" : "Show moments for \(title)")
    }

    @ViewBuilder
    private var avatar: some View {
        if avatarURL != nil {
            StudentAvatarView(
                name: title,
                initials: initials,
                avatarURL: avatarURL,
                cacheKey: avatarCacheKey
            )
            .frame(width: avatarDimension, height: avatarDimension)
            .clipShape(Circle())
            .overlay(avatarBorder)
        } else {
            initialsView
                .frame(width: avatarDimension, height: avatarDimension)
                .overlay(avatarBorder)
        }
    }

    private var initialsView: some View {
        Text(initials)
            .font(.caption.weight(.bold))
            .foregroundStyle(Color(hex: "#3A342E"))
            .frame(width: avatarDimension, height: avatarDimension)
            .background(isSelected ? Color(hex: "#8DA67A").opacity(0.18) : Color(hex: "#FFFDF8"))
            .clipShape(Circle())
    }

    private var avatarBorder: some View {
        Circle()
            .stroke(isSelected ? Color(hex: "#6B8659") : Color(hex: "#E6D8C2"), lineWidth: isSelected ? 2 : 1)
    }
}

private struct PortfolioEntryAudioPlayerView: View {
    let url: URL
    let durationText: String?

    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var endObserver: NSObjectProtocol?

    var body: some View {
        HStack(spacing: 14) {
            Button(action: togglePlayback) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Color(hex: "#6B8659"))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text("Child voice")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hex: "#3A342E"))

                if let durationText {
                    Text(durationText)
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#6E6456"))
                }
            }

            Spacer()
        }
        .padding(14)
        .background(Color(hex: "#F5EDE0"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onDisappear {
            stopPlayback()
            teardownPlayer()
        }
    }

    private func setupPlayerIfNeeded() {
        guard player == nil else {
            return
        }

        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            isPlaying = false
        }
    }

    private func togglePlayback() {
        setupPlayerIfNeeded()
        guard let player else {
            return
        }

        if isPlaying {
            player.pause()
            isPlaying = false
            return
        }

        player.play()
        isPlaying = true
    }

    private func stopPlayback() {
        player?.pause()
        isPlaying = false
        player?.seek(to: .zero)
    }

    private func teardownPlayer() {
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
        player?.pause()
        player = nil
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
        case .audio(let url, let duration):
            PortfolioEntryAudioPlayerView(url: url, durationText: duration)
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
        if let bodyText = entry.bodyText ?? entry.childVoicePrompt {
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
