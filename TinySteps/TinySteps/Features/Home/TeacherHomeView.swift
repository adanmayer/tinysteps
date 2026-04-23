import SwiftUI
import MBAPI

struct TeacherHomeView: View {
    let session: AuthSession
    let classContext: ClassContext
    let selectedClass: MBClass?
    let selectedContextTitle: String
    let selectedContextSubtitle: String
    let canShowClassSwitcher: Bool
    let classesService: ClassesService
    let portfolioService: PortfolioService
    let faceEnrollmentStore: FaceEnrollmentStore
    let faceCaptureDraftStore: FaceCaptureDraftStore
    let observationDraftStore: ObservationCaptureDraftStore
    let observationDraftPublisher: ObservationDraftPublishing
    let observationTaggingService: ObservationTaggingService
    let observationStandardTaggingService: ObservationStandardTaggingService
    let standardsLoadingService: MBStandardsLoadingService
    let onClearCache: () async -> Void
    let observationSpeechTranscriber: ObservationSpeechTranscribing
    let observationChildMatcher: ObservationChildNameMatching
    let onShowClassSwitcher: () -> Void
    let onSignOut: () -> Void

    @State private var selectedTab: Int = 0
    @State private var selectedStudent: ClassRosterStudent?
    @State private var rosterReloadToken = UUID()
    @State private var captureSession: FaceCaptureSession?
    @State private var observationCaptureSession: ObservationCaptureSession?
    @State private var childVoicePickerPresentation: ChildVoicePickerPresentation?
    @State private var directChildVoiceCapturePresentation: DirectChildVoiceCapturePresentation?
    @State private var reviewDraftCount = 0
    @State private var streamCaptureReviewBaselines: [UUID: Int] = [:]

    var body: some View {
        TabView(selection: $selectedTab) {
            streamTab
                .tag(0)
                .tabItem {
                    Label("Stream", systemImage: "rectangle.stack")
                }

            reviewTab
                .tag(1)
                .tabItem {
                    Label("Review", systemImage: "checkmark.circle")
                }
                .badge(reviewDraftCount)

            ClassRosterView(
                session: session,
                classContext: classContext,
                selectedClass: selectedClass,
                selectedContextTitle: selectedContextTitle,
                selectedContextSubtitle: selectedContextSubtitle,
                canShowClassSwitcher: canShowClassSwitcher,
                classesService: classesService,
                faceEnrollmentStore: faceEnrollmentStore,
                onShowClassSwitcher: onShowClassSwitcher,
                onSignOut: onSignOut,
                onCaptureImage: { students in
                    presentImageCapture(
                        students: students,
                        shouldSwitchToReviewAfterCapture: false
                    )
                },
                onCaptureObservation: { launchContext in
                    presentObservationCapture(
                        launchContext,
                        shouldSwitchToReviewAfterCapture: false
                    )
                },
                onCaptureChildVoice: { students in
                    presentChildVoicePicker(
                        students: students,
                        shouldSwitchToReviewAfterCapture: false
                    )
                },
                onClearCache: {
                    await onClearCache()
                },
                onTapStudent: { selectedStudent = $0 }
            )
            .id(rosterReloadToken)
            .tag(2)
            .tabItem {
                Label("Class", systemImage: "person.3")
            }
        }
        .tabViewStyle(.automatic)
        .toolbar(.visible, for: .tabBar)
        .task(id: selectedClass?.id) {
            await refreshReviewDraftCount()
        }
        .fullScreenCover(item: $captureSession) { selectedCaptureSession in
            FaceCaptureView(
                session: session,
                captureSession: selectedCaptureSession,
                faceEnrollmentStore: faceEnrollmentStore,
                draftStore: faceCaptureDraftStore,
                onSaved: {
                    self.captureSession = nil
                    Task {
                        await finishCaptureFlow(
                            captureID: selectedCaptureSession.id,
                            saved: true
                        )
                    }
                }
            )
        }
        .fullScreenCover(item: $observationCaptureSession) { selectedObservationSession in
                ObservationCaptureView(
                    captureSession: selectedObservationSession,
                    speechTranscriber: observationSpeechTranscriber,
                    taggingService: observationTaggingService,
                    standardTaggingService: observationStandardTaggingService,
                    standardsLoadingService: standardsLoadingService,
                    childMatcher: observationChildMatcher,
                    draftStore: observationDraftStore,
                    session: session,
                onDismiss: {
                    self.observationCaptureSession = nil
                    Task {
                        await finishCaptureFlow(
                            captureID: selectedObservationSession.id,
                            saved: nil
                        )
                    }
                }
            )
        }
        .sheet(item: $childVoicePickerPresentation) { presentation in
            ChildVoiceStudentPickerSheet(
                children: presentation.children,
                onSelect: { child in
                    presentDirectChildVoiceCapture(
                        for: child,
                        shouldSwitchToReviewAfterCapture: presentation.shouldSwitchToReviewAfterCapture
                    )
                }
            )
        }
        .fullScreenCover(item: $directChildVoiceCapturePresentation) { presentation in
            ChildVoiceCaptureView(
                session: ChildVoiceCaptureSession(
                    mode: .standaloneNote(
                        classID: presentation.classID,
                        className: presentation.className,
                        child: presentation.child
                    )
                ),
                onSaved: { draft in
                    Task {
                        let didSave = await saveDirectChildVoiceDraft(
                            draft,
                            classID: presentation.classID,
                            className: presentation.className
                        )
                        directChildVoiceCapturePresentation = nil
                        await finishCaptureFlow(
                            captureID: presentation.id,
                            saved: didSave
                        )
                    }
                }
            )
        }
        .sheet(item: $selectedStudent) { student in
            ClassRosterStudentSetupSheet(
                student: student,
                onDismiss: { selectedStudent = nil },
                onSetupCompleted: {
                    selectedStudent = nil
                    rosterReloadToken = UUID()
                },
                faceEnrollmentStore: faceEnrollmentStore
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(20)
        }
    }

    private var streamTab: some View {
        PortfolioTimelineView(
            session: session,
            classContext: classContext,
            selectedClass: selectedClass,
            selectedScopeTitle: selectedContextTitle,
            selectedScopeSubtitle: selectedContextSubtitle,
            canShowScopeSwitcher: canShowClassSwitcher,
            portfolioService: portfolioService,
            classesService: classesService,
            onShowScopeSwitcher: onShowClassSwitcher,
            onCaptureObservation: launchStreamObservationCapture,
            onCaptureImage: launchStreamImageCapture,
            onCaptureChildVoice: launchStreamChildVoiceCapture
        )
        .id(streamIdentity)
    }

    private var reviewTab: some View {
        ObservationReviewQueueView(
            session: session,
            classContext: classContext,
            selectedClass: selectedClass,
            selectedContextTitle: selectedContextTitle,
            canShowClassSwitcher: canShowClassSwitcher,
            draftStore: observationDraftStore,
            photoDraftStore: faceCaptureDraftStore,
            faceEnrollmentStore: faceEnrollmentStore,
            publisher: observationDraftPublisher,
            observationSpeechTranscriber: observationSpeechTranscriber,
            observationTaggingService: observationTaggingService,
            observationStandardTaggingService: observationStandardTaggingService,
            observationStandardsLoadingService: standardsLoadingService,
            classesService: classesService,
            observationChildMatcher: observationChildMatcher,
            onShowClassSwitcher: onShowClassSwitcher,
            onDraftsChanged: { count in
                reviewDraftCount = count
            }
        )
        .id(reviewQueueIdentity)
    }

    private var reviewQueueIdentity: String {
        classContext.apiClassID ?? "all-classes"
    }

    private var streamIdentity: String {
        streamClassID ?? "all-classes"
    }

    private var streamClassID: String? {
        guard let classID = classContext.apiClassID, selectedClass?.id == classID else {
            return nil
        }

        return classID
    }

    private var directChildVoiceClassName: String {
        let title = selectedContextTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty == false {
            return title
        }

        return selectedClass?.displayName ?? "Class"
    }

    private func presentImageCapture(
        students: [ClassRosterStudent],
        shouldSwitchToReviewAfterCapture: Bool
    ) {
        guard let selectedClass else {
            return
        }

        let selectedCaptureSession = FaceCaptureSession(
            classID: selectedClass.id,
            className: directChildVoiceClassName,
            rosterSnapshot: students.map(FaceCaptureStudentSnapshot.init)
        )
        if shouldSwitchToReviewAfterCapture {
            streamCaptureReviewBaselines[selectedCaptureSession.id] = reviewDraftCount
        }
        captureSession = selectedCaptureSession
    }

    private func presentObservationCapture(
        _ launchContext: ObservationCaptureLaunchContext,
        shouldSwitchToReviewAfterCapture: Bool
    ) {
        let selectedObservationSession = ObservationCaptureSession(launchContext: launchContext)
        if shouldSwitchToReviewAfterCapture {
            streamCaptureReviewBaselines[selectedObservationSession.id] = reviewDraftCount
        }
        observationCaptureSession = selectedObservationSession
    }

    private func presentChildVoicePicker(
        students: [ClassRosterStudent],
        shouldSwitchToReviewAfterCapture: Bool
    ) {
        let candidates = directChildVoiceCandidates(from: students)
        guard candidates.isEmpty == false else {
            return
        }

        childVoicePickerPresentation = ChildVoicePickerPresentation(
            children: candidates,
            shouldSwitchToReviewAfterCapture: shouldSwitchToReviewAfterCapture
        )
    }

    private func presentDirectChildVoiceCapture(
        for child: ChildVoiceChild,
        shouldSwitchToReviewAfterCapture: Bool
    ) {
        guard let selectedClass else {
            childVoicePickerPresentation = nil
            return
        }

        let classID = selectedClass.id
        let className = directChildVoiceClassName
        childVoicePickerPresentation = nil

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            let presentation = DirectChildVoiceCapturePresentation(
                classID: classID,
                className: className,
                child: child
            )
            if shouldSwitchToReviewAfterCapture {
                streamCaptureReviewBaselines[presentation.id] = reviewDraftCount
            }
            directChildVoiceCapturePresentation = presentation
        }
    }

    private func launchStreamImageCapture() {
        Task {
            guard let students = await loadSelectedClassRosterStudents(),
                  students.isEmpty == false else {
                return
            }

            presentImageCapture(
                students: students,
                shouldSwitchToReviewAfterCapture: true
            )
        }
    }

    private func launchStreamObservationCapture() {
        Task {
            guard let students = await loadSelectedClassRosterStudents(),
                  let launchContext = makeObservationLaunchContext(students: students) else {
                return
            }

            presentObservationCapture(
                launchContext,
                shouldSwitchToReviewAfterCapture: true
            )
        }
    }

    private func launchStreamChildVoiceCapture() {
        Task {
            guard let students = await loadSelectedClassRosterStudents(),
                  students.isEmpty == false else {
                return
            }

            presentChildVoicePicker(
                students: students,
                shouldSwitchToReviewAfterCapture: true
            )
        }
    }

    private func makeObservationLaunchContext(students: [ClassRosterStudent]) -> ObservationCaptureLaunchContext? {
        guard let selectedClass, let classID = streamClassID else {
            return nil
        }

        return ObservationCaptureLaunchContext(
            classID: classID,
            className: directChildVoiceClassName,
            selectedClass: selectedClass,
            rosterSnapshot: students.map(ObservationRosterStudent.init)
        )
    }

    private func loadSelectedClassRosterStudents() async -> [ClassRosterStudent]? {
        guard let classID = streamClassID else {
            return nil
        }

        do {
            let members = try await classesService.loadClassStudents(for: session, classID: classID)
            let memberKeys = members.map(\.rosterStudentKey)
            let statuses = (try? await faceEnrollmentStore.statuses(for: memberKeys)) ?? [:]

            return members
                .sorted { $0.rosterStudentKey < $1.rosterStudentKey }
                .map { member in
                    ClassRosterStudent.from(
                        member: member,
                        status: statuses[member.rosterStudentKey] ?? .needsSetup,
                        presence: .present
                    )
                }
        } catch {
            return nil
        }
    }

    private func directChildVoiceCandidates(from students: [ClassRosterStudent]) -> [ChildVoiceChild] {
        students.compactMap { student in
            guard let rawUserID = student.userID?.trimmingCharacters(in: .whitespacesAndNewlines),
                  rawUserID.isEmpty == false else {
                return nil
            }

            let studentKey = student.studentKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard studentKey.isEmpty == false else {
                return nil
            }

            let displayName = student.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            let childDisplayName = displayName.isEmpty ? "Child" : displayName

            return ChildVoiceChild(
                studentKey: studentKey,
                userID: rawUserID,
                displayName: childDisplayName,
                avatarURL: student.avatarURL
            )
        }
    }

    private func saveDirectChildVoiceDraft(
        _ childVoiceDraft: ChildVoiceDraft,
        classID: String,
        className: String
    ) async -> Bool {
        let trimmedUserID = childVoiceDraft.childUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedUserID.isEmpty == false else {
            return false
        }

        let childName = childVoiceDraft.childDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)

        let draft = ObservationCaptureDraft(
            classID: classID,
            className: className,
            transcript: "\(childName) voice",
            matchedChildren: [
                ObservationMatchedChild(
                    studentKey: childVoiceDraft.childStudentKey,
                    userID: trimmedUserID,
                    displayName: childName,
                    matchText: childName,
                    confidence: 1
                )
            ],
            tags: .empty,
            standardTagSuggestions: [],
            confidence: 0,
            evidenceSpans: [],
            pendingRetag: false,
            dismissedChildMatchKeys: [],
            childVoice: childVoiceDraft,
            status: .savedForReview,
            createdAt: childVoiceDraft.createdAt,
            updatedAt: childVoiceDraft.createdAt
        )

        do {
            _ = try await observationDraftStore.saveDraft(draft)
            return true
        } catch {
            // Keep local behavior unchanged for now.
            return false
        }
    }

    private func finishCaptureFlow(captureID: UUID, saved: Bool?) async {
        await refreshReviewDraftCount()

        guard let baselineCount = streamCaptureReviewBaselines.removeValue(forKey: captureID) else {
            return
        }

        let shouldSwitchToReview = saved ?? (reviewDraftCount > baselineCount)
        if shouldSwitchToReview {
            selectedTab = 1
        }
    }

    private func refreshReviewDraftCount() async {
        guard let classID = classContext.apiClassID, selectedClass?.id == classID else {
            reviewDraftCount = 0
            return
        }

        do {
            let drafts = try await observationDraftStore.loadDrafts(forClassID: classID)
            let photoDrafts = try await faceCaptureDraftStore.loadDrafts(forClassID: classID)
            reviewDraftCount = drafts.filter { $0.status == .savedForReview }.count + photoDrafts.count
        } catch {
            reviewDraftCount = 0
        }
    }

}

private struct ChildVoicePickerPresentation: Identifiable {
    let id = UUID()
    let children: [ChildVoiceChild]
    let shouldSwitchToReviewAfterCapture: Bool
}

private struct DirectChildVoiceCapturePresentation: Identifiable {
    let id = UUID()
    let classID: String
    let className: String
    let child: ChildVoiceChild
}

#if DEBUG
struct TeacherHomeView_Previews: PreviewProvider {
    static var previews: some View {
        TeacherHomeView(
            session: .previewTeacher,
            classContext: .allClasses,
            selectedClass: nil,
            selectedContextTitle: "All Classes",
            selectedContextSubtitle: "3 classes",
            canShowClassSwitcher: true,
            classesService: MBClassesService.preview(),
            portfolioService: MBPortfolioService.preview(),
            faceEnrollmentStore: FaceEnrollmentStoreUnavailable(),
            faceCaptureDraftStore: InMemoryFaceCaptureDraftStore(),
            observationDraftStore: InMemoryObservationCaptureDraftStore(),
            observationDraftPublisher: UnavailableObservationDraftPublisher(),
            observationTaggingService: DisabledObservationTaggingService(),
            observationStandardTaggingService: DisabledObservationStandardTaggingService(),
            standardsLoadingService: MBStandardsLoadingServiceImpl.preview(),
            onClearCache: {},
            observationSpeechTranscriber: PreviewObservationSpeechTranscriber(),
            observationChildMatcher: LocalObservationChildNameMatcher(),
            onShowClassSwitcher: {},
            onSignOut: {}
        )
    }
}
#endif
