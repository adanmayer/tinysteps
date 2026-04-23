import SwiftUI
import MBAPI
import UIKit

struct ObservationReviewQueueView: View {
    @State private var model: ObservationReviewQueueModel
    @State private var pendingDeleteItem: PortfolioReviewItem?
    @State private var editingDraft: ObservationCaptureDraft?

    private let selectedContextTitle: String
    private let session: AuthSession
    private let selectedClass: MBClass?
    private let draftStore: ObservationCaptureDraftStore
    private let photoDraftStore: FaceCaptureDraftStore
    private let canShowClassSwitcher: Bool
    private let onShowClassSwitcher: () -> Void
    private let onDraftsChanged: (Int) -> Void
    private let observationSpeechTranscriber: ObservationSpeechTranscribing
    private let observationTaggingService: ObservationTaggingService
    private let observationStandardTaggingService: ObservationStandardTaggingService
    private let observationStandardsLoadingService: MBStandardsLoadingService
    private let observationChildMatcher: ObservationChildNameMatching
    private let classesService: ClassesService

    @State private var classRosterSnapshot: [ObservationRosterStudent] = []

    init(
        session: AuthSession,
        classContext: ClassContext,
        selectedClass: MBClass?,
        selectedContextTitle: String,
        canShowClassSwitcher: Bool,
        draftStore: ObservationCaptureDraftStore,
        photoDraftStore: FaceCaptureDraftStore,
        publisher: ObservationDraftPublishing,
        observationSpeechTranscriber: ObservationSpeechTranscribing,
        observationTaggingService: ObservationTaggingService,
        observationStandardTaggingService: ObservationStandardTaggingService,
        observationStandardsLoadingService: MBStandardsLoadingService,
        classesService: ClassesService,
        observationChildMatcher: ObservationChildNameMatching,
        onShowClassSwitcher: @escaping () -> Void,
        onDraftsChanged: @escaping (Int) -> Void
    ) {
        self.selectedContextTitle = selectedContextTitle
        self.session = session
        self.selectedClass = selectedClass
        self.draftStore = draftStore
        self.photoDraftStore = photoDraftStore
        self.canShowClassSwitcher = canShowClassSwitcher
        self.onShowClassSwitcher = onShowClassSwitcher
        self.onDraftsChanged = onDraftsChanged
        self.observationSpeechTranscriber = observationSpeechTranscriber
        self.observationTaggingService = observationTaggingService
        self.observationStandardTaggingService = observationStandardTaggingService
        self.observationStandardsLoadingService = observationStandardsLoadingService
        self.classesService = classesService
        self.observationChildMatcher = observationChildMatcher

        let classID = Self.resolvedClassID(
            classContext: classContext,
            selectedClass: selectedClass
        )
        let className = selectedContextTitle.isEmpty
            ? selectedClass?.displayName ?? "Class"
            : selectedContextTitle

        _model = State(
            initialValue: ObservationReviewQueueModel(
                session: session,
                classID: classID,
                className: className,
                selectedClass: selectedClass,
                draftStore: draftStore,
                photoDraftStore: photoDraftStore,
                publisher: publisher
            )
        )
    }

    var body: some View {
        ZStack {
            Color(hex: "#FBF6EE")
                .ignoresSafeArea()

            if model.hasConcreteClass {
                reviewContent
            } else {
                chooseClassStateView
            }
        }
        .task(id: model.classID) {
            await model.load()
            onDraftsChanged(model.reviewCount)
            await loadClassRosterSnapshot()
        }
        .onChange(of: model.reviewCount) { _, count in
            onDraftsChanged(count)
        }
        .fullScreenCover(item: $editingDraft) { draft in
            ObservationCaptureView(
                captureSession: ObservationCaptureSession(
                    classID: draft.classID,
                    className: draft.className,
                    selectedClass: selectedClass ?? Self.sessionUserPlaceholderClass(for: draft),
                    rosterSnapshot: Self.rosterStudents(
                        from: draft,
                        fallbackTo: classRosterSnapshot
                    ),
                    initialDraftID: draft.id
                ),
                speechTranscriber: observationSpeechTranscriber,
                taggingService: observationTaggingService,
                standardTaggingService: observationStandardTaggingService,
                standardsLoadingService: observationStandardsLoadingService,
                childMatcher: observationChildMatcher,
                draftStore: draftStore,
                session: session,
                onDismiss: {
                    editingDraft = nil
                    Task {
                        await model.load()
                        onDraftsChanged(model.reviewCount)
                    }
                }
            )
        }
        .confirmationDialog(
            "Delete this draft?",
            isPresented: Binding(
                get: { pendingDeleteItem != nil },
                set: { isPresented in
                    if isPresented == false {
                        pendingDeleteItem = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete draft", role: .destructive) {
                guard let item = pendingDeleteItem else {
                    return
                }

                Task {
                    await model.deleteItem(item.id)
                    onDraftsChanged(model.reviewCount)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the local review item from this device.")
        }
        .safeAreaInset(edge: .bottom) {
            if model.filteredItems.isEmpty == false {
                bulkPublishBar
            }
        }
    }

    private func loadClassRosterSnapshot() async {
        guard let classID = model.classID,
              let selectedClass,
              selectedClass.id == classID else {
            classRosterSnapshot = []
            return
        }

        do {
            let members = try await classesService.loadClassStudents(
                for: session,
                classID: classID
            )
            classRosterSnapshot = members.map(Self.observationRosterStudent(from:))
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        } catch {
            if classRosterSnapshot.isEmpty {
                classRosterSnapshot = []
            }
        }
    }

    private var reviewContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            filterStrip

            if let message = model.errorMessage {
                messageBanner(message, color: Color(hex: "#C97A6E"), systemImage: "exclamationmark.triangle.fill")
            } else if let message = model.statusMessage {
                messageBanner(message, color: Color(hex: "#6E6456"), systemImage: "checkmark.circle.fill")
            }

            Group {
                if model.isLoading {
                    ProgressView("Loading review queue…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if model.reviewItems.isEmpty {
                    emptyStateView
                } else if model.filteredItems.isEmpty {
                    filteredEmptyStateView
                } else {
                    draftFeed
                }
            }
        }
    }

    private var header: some View {
        ClassPageTitleHeader(
            title: "Review",
            classTitle: classPickerTitle,
            canShowClassSwitcher: canShowClassSwitcher,
            onShowClassSwitcher: onShowClassSwitcher
        )
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Review")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color(hex: "#3A342E"))
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text(reviewSubtitle)
                .font(.footnote)
                .foregroundStyle(Color(hex: "#6E6456"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ObservationReviewFilter.allCases) { filter in
                    Button {
                        model.selectedFilter = filter
                    } label: {
                        HStack(spacing: 8) {
                            if let systemImage = filter.systemImage {
                                Image(systemName: systemImage)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            Text(filter.rawValue)
                                .font(.footnote.weight(.medium))
                        }
                        .foregroundStyle(model.selectedFilter == filter ? Color(hex: "#6B8659") : Color(hex: "#3A342E"))
                        .padding(.horizontal, 16)
                        .frame(height: 36)
                        .background(filterBackground(for: filter))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(
                                    model.selectedFilter == filter
                                    ? Color(hex: "#6B8659")
                                    : Color(hex: "#E6D8C2"),
                                    lineWidth: model.selectedFilter == filter ? 1.5 : 0.5
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 2)
        }
        .padding(.top, 22)
        .padding(.bottom, 12)
    }

    private var draftFeed: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(model.filteredItems) { item in
                    ObservationReviewItemCard(
                        item: item,
                        isSeen: model.isSeen(item.id),
                        isActing: model.isActing(on: item.id),
                        onSeen: {
                            model.markSeen(item.id)
                        },
                        onPublish: {
                            Task {
                                await model.publish(item.id)
                                onDraftsChanged(model.reviewCount)
                            }
                        },
                        onEdit: {
                            editingDraft = item.noteDraft
                        },
                        onDelete: {
                            pendingDeleteItem = item
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 116)
        }
    }

    private var bulkPublishBar: some View {
        VStack(spacing: 6) {
            Button {
                Task {
                    await model.publishSeen()
                    onDraftsChanged(model.reviewCount)
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text(bulkPublishTitle)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [
                            Color(hex: "#8DA67A"),
                            Color(hex: "#6B8659")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .opacity(model.canPublishSeen ? 1 : 0.48)
                )
                .clipShape(Capsule())
                .shadow(color: Color(hex: "#6E6456").opacity(model.canPublishSeen ? 0.24 : 0.08), radius: 18, x: 0, y: 8)
            }
            .buttonStyle(.plain)
            .disabled(!model.canPublishSeen)

        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Color(hex: "#FBF6EE").opacity(0.92))
    }

    private var chooseClassStateView: some View {
        VStack(spacing: 14) {
            HStack {
                Button(action: onShowClassSwitcher) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color(hex: "#8DA67A"))
                            .frame(width: 8, height: 8)
                        Text("Choose a class")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color(hex: "#3A342E"))
                        Image(systemName: "chevron.down")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(hex: "#6E6456"))
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(Color(hex: "#FFFDF8").opacity(0.95))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color(hex: "#D8CEBD"), lineWidth: 0.5)
                    )
                }
                .disabled(!canShowClassSwitcher)

                Spacer()
            }
            .padding(.horizontal, 24)

            Image(systemName: "checkmark.circle")
                .font(.system(size: 44))
                .foregroundStyle(Color(hex: "#8DA67A"))

            Text("Choose a class")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color(hex: "#3A342E"))

            Text("Review drafts are kept per class on this device.")
                .font(.body)
                .foregroundStyle(Color(hex: "#6E6456"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            "Nothing to review. Nice work today.",
            systemImage: "checkmark.seal",
            description: Text("Everything for \(model.className) is up to date.")
        )
        .foregroundStyle(Color(hex: "#6E6456"))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filteredEmptyStateView: some View {
        ContentUnavailableView(
            "No \(model.selectedFilter.rawValue.lowercased()) drafts",
            systemImage: model.selectedFilter.systemImage ?? "tray",
            description: Text("Try All to see the rest of the queue.")
        )
        .foregroundStyle(Color(hex: "#6E6456"))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func messageBanner(
        _ message: String,
        color: Color,
        systemImage: String
    ) -> some View {
        Label(message, systemImage: systemImage)
            .font(.footnote.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "#FFFDF8").opacity(0.86))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
    }

    private func filterBackground(for filter: ObservationReviewFilter) -> Color {
        if model.selectedFilter == filter {
            return Color(hex: "#8DA67A").opacity(0.14)
        }
        return Color(hex: "#F5EDE0")
    }

    private var classPickerTitle: String {
        selectedContextTitle.isEmpty ? model.className : selectedContextTitle
    }

    private var reviewSubtitle: String {
        let count = model.reviewCount
        return "\(formattedToday()) · \(count) \(count == 1 ? "moment" : "moments") waiting"
    }

    private var bulkPublishTitle: String {
        if model.seenReadyCount > 0 {
            return "Publish \(model.seenReadyCount) seen \(model.seenReadyCount == 1 ? "moment" : "moments")"
        }

        if model.readyCount > 0 {
            return "Scroll to confirm moments"
        }

        return "Waiting for ready moments"
    }

    private func formattedToday() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: Date())
    }

    private static func resolvedClassID(
        classContext: ClassContext,
        selectedClass: MBClass?
    ) -> String? {
        guard
            let contextClassID = classContext.apiClassID,
            selectedClass?.id == contextClassID
        else {
            return nil
        }

        return contextClassID
    }

    private static func sessionUserPlaceholderClass(for draft: ObservationCaptureDraft) -> MBClass {
        MBClass(
            id: draft.classID,
            displayName: draft.className,
            iconName: "",
            isLocked: false,
            isMember: true
        )
    }

    private static func rosterStudents(
        from draft: ObservationCaptureDraft,
        fallbackTo fullRoster: [ObservationRosterStudent]
    ) -> [ObservationRosterStudent] {
        guard fullRoster.isEmpty == false else {
            return rosterStudents(for: draft)
        }

        let draftStudents = rosterStudents(for: draft)
        let fullKeys = Set(fullRoster.map(\.studentKey))
        let missing = draftStudents.filter { fullKeys.contains($0.studentKey) == false }

        return fullRoster + missing
    }

    private static func observationRosterStudent(from member: MBMember) -> ObservationRosterStudent {
        let displayName = member.preferredDisplayName
        return ObservationRosterStudent(
            id: member.rosterStudentKey,
            studentKey: member.rosterStudentKey,
            userID: member.user.id,
            displayName: displayName,
            firstName: displayName,
            initials: reviewDraftInitials(from: displayName)
        )
    }

    private static func rosterStudents(for draft: ObservationCaptureDraft) -> [ObservationRosterStudent] {
        var students: [ObservationRosterStudent] = []
        var seenStudentKeys: Set<String> = []

        for child in draft.matchedChildren {
            guard seenStudentKeys.insert(child.studentKey).inserted else {
                continue
            }

            let firstName = child.displayName.split(separator: " ").first.map(String.init) ?? child.displayName
            students.append(
                ObservationRosterStudent(
                    id: child.id,
                    studentKey: child.studentKey,
                    userID: child.userID,
                    displayName: child.displayName,
                    firstName: firstName,
                    initials: Self.reviewDraftInitials(from: child.displayName)
                )
            )
        }
        return students
    }

    private static func reviewDraftInitials(from displayName: String) -> String {
        let parts = displayName.split(separator: " ").prefix(2)
        let initials = parts
            .compactMap(\.first)
            .map(String.init)
            .joined()
        return initials.isEmpty ? String(displayName.prefix(2)).uppercased() : initials.uppercased()
    }
}

private struct ObservationReviewItemCard: View {
    let item: PortfolioReviewItem
    let isSeen: Bool
    let isActing: Bool
    let onSeen: () -> Void
    let onPublish: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var isReady: Bool {
        ObservationReviewQueueModel.isReadyForPublish(item)
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 14) {
                header
                content
                tagSection
                Divider()
                    .background(Color(hex: "#E6D8C2").opacity(0.7))
                footer
            }
            .padding(18)
        }
        .background(Color(hex: "#FFFDF8"))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color(hex: "#F1E7D8"), lineWidth: 0.6)
        )
        .shadow(color: .black.opacity(0.05), radius: 16, x: 0, y: 8)
        .task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if Task.isCancelled == false {
                onSeen()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Menu {
                Button("Delete draft", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .frame(width: 28, height: 28)
                    .background(Color(hex: "#F5EDE0"))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Text(draft.reviewHeaderText)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color(hex: "#6E6456"))
                .lineLimit(1)
                .minimumScaleFactor(0.76)

            Spacer()

            if isReady {
                Circle()
                    .fill(isSeen ? Color(hex: "#8DA67A") : Color(hex: "#D99B8F"))
                    .frame(width: 7, height: 7)
                    .accessibilityHidden(true)
            } else {
                Text("Draft")
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(Color(hex: "#A89E8F"))
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .note:
            if let draft = item.noteDraft {
                Text(draft.transcript)
                    .font(.body)
                    .lineSpacing(7)
                    .foregroundStyle(Color(hex: "#3A342E"))
                    .lineLimit(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Observation draft")
            }
        case .photo:
            if let photoDraft = item.photoDraft, let image = UIImage(data: photoDraft.imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 188)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color(hex: "#E6D8C2"), lineWidth: 0.6)
                    )
                    .accessibilityLabel("Captured photo draft")
            } else {
                Label("Photo preview unavailable", systemImage: "photo")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color(hex: "#A9772D"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var tagSection: some View {
        switch item.kind {
        case .note:
            if let draft = item.noteDraft {
                let tags = draft.reviewTagValues
                if tags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            ReviewSkeletonChip(width: 132)
                            ReviewSkeletonChip(width: 104)
                        }

                        Text(draft.pendingRetag ? "Tags catching up..." : "No tags yet")
                            .font(.caption)
                            .foregroundStyle(Color(hex: "#A9772D"))
                            .italic()
                    }
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 110), spacing: 8)],
                        alignment: .leading,
                        spacing: 8
                    ) {
                        ForEach(tags, id: \.self) { tag in
                            ReviewTagChip(label: tag)
                        }
                    }
                }
            }
        case .photo:
            ReviewTagChip(label: "Photo")
        }
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 12) {
            avatarRow

            Spacer(minLength: 8)

            if item.kind == .note {
                Button("Edit", action: onEdit)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(hex: "#3A342E"))
                    .buttonStyle(.plain)
                    .disabled(isActing)
            }

            Button(action: onPublish) {
                Text(publishTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isReady ? .white : Color(hex: "#A89E8F"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .padding(.horizontal, 16)
                    .frame(height: 36)
                    .background(
                        Capsule()
                            .fill(publishBackground)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isActing || isReady == false)
        }
    }

    private var avatarRow: some View {
        HStack(spacing: -8) {
            if let draft = item.noteDraft {
                ForEach(Array(draft.matchedChildren.prefix(4))) { child in
                    Text(child.displayName.reviewInitials)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(hex: "#3A342E"))
                        .frame(width: 32, height: 32)
                        .background(Color(hex: "#F5EDE0"))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color(hex: "#8DA67A"), lineWidth: 1)
                        )
                        .accessibilityLabel(child.displayName)
                }

                if draft.matchedChildren.isEmpty {
                    Image(systemName: "person.2")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: "#A89E8F"))
                        .frame(width: 32, height: 32)
                        .background(Color(hex: "#F5EDE0"))
                        .clipShape(Circle())
                        .accessibilityLabel("Class observation")
                }
            } else if let photoDraft = item.photoDraft {
                Image(systemName: "person.2")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "#A89E8F"))
                    .frame(width: 32, height: 32)
                    .background(Color(hex: "#F5EDE0"))
                    .clipShape(Circle())
                    .accessibilityLabel("\(photoDraft.faces.count) detected faces")
            }
        }
    }

    private var publishTitle: String {
        if isActing {
            return "Publishing..."
        }

        return isReady ? "Publish" : "Waiting for tags"
    }

    private var publishBackground: Color {
        if isReady {
            return Color(hex: "#6B8659")
        }

        return Color(hex: "#F5EDE0")
    }

    private var accentColor: Color {
        isReady ? Color(hex: "#8DA67A") : Color(hex: "#E6B469")
    }

    private var draft: ObservationCaptureDraft {
        item.noteDraft ?? ObservationCaptureDraft(
            id: item.id,
            classID: item.classID,
            className: item.className,
            transcript: "Photo",
            pendingRetag: false,
            status: .savedForReview,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt
        )
    }
}

private struct ReviewTagChip: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.footnote.weight(.medium))
            .foregroundStyle(Color(hex: "#6B8659"))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(Color(hex: "#8DA67A").opacity(0.14))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color(hex: "#8DA67A"), lineWidth: 1)
            )
    }
}

private struct ReviewSkeletonChip: View {
    let width: CGFloat

    var body: some View {
        Capsule()
            .fill(Color(hex: "#F5EDE0"))
            .frame(width: width, height: 30)
            .overlay(
                Capsule()
                    .stroke(Color(hex: "#F1E7D8"), lineWidth: 0.5)
            )
    }
}

private extension ObservationCaptureDraft {
    var reviewHeaderText: String {
        "\(reviewPrimaryName) · \(reviewTimeText)"
    }

    var reviewPrimaryName: String {
        matchedChildren.first?.displayName ?? className
    }

    var reviewTimeText: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(updatedAt) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            return formatter.string(from: updatedAt)
        }

        if calendar.isDateInYesterday(updatedAt) {
            return "yesterday"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: updatedAt)
    }

    var reviewTagValues: [String] {
        var values: [String] = []
        if let theme = tags.transdisciplinaryTheme {
            values.append(theme.rawValue)
        }
        values.append(contentsOf: tags.keyConcepts.map(\.rawValue))
        values.append(contentsOf: tags.atlSkills.map(\.rawValue))
        values.append(contentsOf: tags.learnerProfile.map(\.rawValue))

        let standardTagValues = standardTagSuggestions.compactMap { suggestion in
            let tag = suggestion.displayHashtag.isEmpty ? suggestion.title : suggestion.displayHashtag
            let trimmedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedTag.isEmpty ? nil : trimmedTag
        }

        for standardTag in standardTagValues {
            let isDuplicate = values.contains { existing in
                existing.caseInsensitiveCompare(standardTag) == .orderedSame
            }
            if isDuplicate == false {
                values.append(standardTag)
            }
        }

        return values
    }
}

private extension String {
    var reviewInitials: String {
        let parts = split(separator: " ")
        let initials = parts
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
        return initials.isEmpty ? String(prefix(2)).uppercased() : initials.uppercased()
    }
}

#if DEBUG
#Preview {
    TabView {
        ObservationReviewQueueView(
            session: .previewTeacher,
            classContext: .schoolClass(id: "blue-room"),
            selectedClass: MBClass(
                id: "blue-room",
                displayName: "Blue Room",
                iconName: "",
                isLocked: false,
                isMember: true
            ),
            selectedContextTitle: "Blue Room",
            canShowClassSwitcher: true,
            draftStore: ObservationReviewPreviewStore(),
            photoDraftStore: InMemoryFaceCaptureDraftStore(),
            publisher: UnavailableObservationDraftPublisher(),
            observationSpeechTranscriber: PreviewObservationSpeechTranscriber(),
            observationTaggingService: DisabledObservationTaggingService(),
            observationStandardTaggingService: DisabledObservationStandardTaggingService(),
            observationStandardsLoadingService: MBStandardsLoadingServiceImpl.preview(),
            classesService: MBClassesService.preview(),
            observationChildMatcher: LocalObservationChildNameMatcher(),
            onShowClassSwitcher: {},
            onDraftsChanged: { _ in }
        )
        .tabItem {
            Label("Review", systemImage: "checkmark.circle")
        }
    }
}

@MainActor
private struct ObservationReviewPreviewStore: ObservationCaptureDraftStore {
    func saveDraft(_ draft: ObservationCaptureDraft) async throws -> ObservationCaptureDraft.ID {
        draft.id
    }

    func loadDrafts(forClassID classID: String) async throws -> [ObservationCaptureDraft] {
        [
            ObservationCaptureDraft(
                classID: classID,
                className: "Blue Room",
                transcript: "I saw Amara stack the red cups, very carefully, one on top of the other, and she counted them in Somali and English.",
                matchedChildren: [
                    ObservationMatchedChild(studentKey: "amara", displayName: "Amara", matchText: "Amara")
                ],
                tags: ObservationPYPTagBundle(
                    transdisciplinaryTheme: nil,
                    keyConcepts: [.connection],
                    atlSkills: [.thinking],
                    learnerProfile: [.inquirer, .communicator]
                ),
                confidence: 0.82,
                evidenceSpans: [],
                pendingRetag: false,
                status: .savedForReview,
                createdAt: Date().addingTimeInterval(-2400),
                updatedAt: Date().addingTimeInterval(-2400)
            ),
            ObservationCaptureDraft(
                classID: classID,
                className: "Blue Room",
                transcript: "Noor pointed to the clouds and said dragon coming.",
                matchedChildren: [
                    ObservationMatchedChild(studentKey: "noor", displayName: "Noor", matchText: "Noor")
                ],
                tags: ObservationPYPTagBundle(
                    transdisciplinaryTheme: nil,
                    keyConcepts: [],
                    atlSkills: [],
                    learnerProfile: [.communicator]
                ),
                confidence: 0.4,
                evidenceSpans: [],
                pendingRetag: true,
                status: .savedForReview,
                createdAt: Date().addingTimeInterval(-900),
                updatedAt: Date().addingTimeInterval(-900)
            )
        ]
    }

    func deleteDraft(id: ObservationCaptureDraft.ID) async throws {
    }
}
#endif
