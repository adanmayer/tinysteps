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
    let onShowClassSwitcher: () -> Void
    let onSignOut: () -> Void

    @State private var selectedTab: Int = 2
    @State private var selectedStudent: ClassRosterStudent?
    @State private var rosterReloadToken = UUID()

    var body: some View {
        TabView(selection: $selectedTab) {
            placeholderTab("Today", systemImage: "camera")
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
            onShowClassSwitcher: {},
            onSignOut: {}
        )
    }
}
#endif
