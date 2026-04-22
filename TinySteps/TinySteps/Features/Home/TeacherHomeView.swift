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
    @State private var reviewDraftCount = 0

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
                onShowClassSettings: {
                    selectedStudent = nil
                },
                onCaptureImage: { students in
                    guard let selectedClass else {
                        return
                    }
                    captureSession = FaceCaptureSession(
                        classID: selectedClass.id,
                        className: selectedContextTitle,
                        rosterSnapshot: students.map(FaceCaptureStudentSnapshot.init)
                    )
                },
                onCaptureObservation: { launchContext in
                    observationCaptureSession = ObservationCaptureSession(launchContext: launchContext)
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
                        await refreshReviewDraftCount()
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
            onShowScopeSwitcher: onShowClassSwitcher
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
            publisher: observationDraftPublisher,
            observationSpeechTranscriber: observationSpeechTranscriber,
            observationTaggingService: observationTaggingService,
            observationStandardTaggingService: observationStandardTaggingService,
            observationStandardsLoadingService: standardsLoadingService,
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

    private func refreshReviewDraftCount() async {
        guard let classID = classContext.apiClassID, selectedClass?.id == classID else {
            reviewDraftCount = 0
            return
        }

        do {
            let drafts = try await observationDraftStore.loadDrafts(forClassID: classID)
            reviewDraftCount = drafts.filter { $0.status == .savedForReview }.count
        } catch {
            reviewDraftCount = 0
        }
    }

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
