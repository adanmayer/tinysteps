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
    let faceEnrollmentStore: FaceEnrollmentStore
    let faceCaptureDraftStore: FaceCaptureDraftStore
    let observationDraftStore: ObservationCaptureDraftStore
    let observationTaggingService: ObservationTaggingService
    let standardsLoadingService: MBStandardsLoadingService
    let observationSpeechTranscriber: ObservationSpeechTranscribing
    let observationChildMatcher: ObservationChildNameMatching
    let onShowClassSwitcher: () -> Void
    let onSignOut: () -> Void

    @State private var selectedTab: Int = 2
    @State private var selectedStudent: ClassRosterStudent?
    @State private var rosterReloadToken = UUID()
    @State private var captureSession: FaceCaptureSession?
    @State private var observationCaptureSession: ObservationCaptureSession?

    var body: some View {
        TabView(selection: $selectedTab) {
            todayTab
                .tag(0)
                .tabItem {
                    Label("Today", systemImage: "camera")
                }

            placeholderTab("Review", systemImage: "checkmark.circle")
                .tag(1)
                .tabItem {
                    Label("Review", systemImage: "checkmark.circle")
                }

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
                onTapStudent: { selectedStudent = $0 }
            )
            .id(rosterReloadToken)
            .tag(2)
            .tabItem {
                Label("Class", systemImage: "person.3")
            }
        }
        .tabViewStyle(.automatic)
        .onAppear {
            selectedTab = 2
        }
        .toolbar(.visible, for: .tabBar)
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
                standardsLoadingService: standardsLoadingService,
                childMatcher: observationChildMatcher,
                draftStore: observationDraftStore,
                session: session,
                onDismiss: {
                    self.observationCaptureSession = nil
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

    private var todayTab: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "camera")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text("Today")
                .font(.title3.weight(.semibold))
            Text("Placeholder tab for Today.")
                .foregroundStyle(.secondary)

            Button(role: .destructive, action: onSignOut) {
                Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
            .accessibilityLabel("Sign out")

            Spacer()
        }
        .padding(.top, 16)
    }

    private func placeholderTab(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: systemImage)
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.weight(.semibold))
            Text("Placeholder tab for \(title).")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.top, 16)
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
                faceEnrollmentStore: FaceEnrollmentStoreUnavailable(),
                faceCaptureDraftStore: InMemoryFaceCaptureDraftStore(),
                observationDraftStore: InMemoryObservationCaptureDraftStore(),
                observationTaggingService: DisabledObservationTaggingService(),
                standardsLoadingService: MBStandardsLoadingServiceImpl.preview(),
                observationSpeechTranscriber: PreviewObservationSpeechTranscriber(),
                observationChildMatcher: LocalObservationChildNameMatcher(),
                onShowClassSwitcher: {},
                onSignOut: {}
            )
        }
    }
#endif
