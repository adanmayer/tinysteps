import SwiftUI
import MBAPI

struct ClassRosterView: View {
    let session: AuthSession
    let classContext: ClassContext
    let selectedClass: MBClass?
    let selectedContextTitle: String
    let selectedContextSubtitle: String
    let onShowClassSwitcher: () -> Void
    let onSignOut: () -> Void
    let onCaptureImage: ([ClassRosterStudent]) -> Void
    let onCaptureObservation: (ObservationCaptureLaunchContext) -> Void
    let onClearCache: () async -> Void
    let canShowClassSwitcher: Bool
    let onTapStudent: (ClassRosterStudent) -> Void
    let classesService: ClassesService
    let faceEnrollmentStore: FaceEnrollmentStore

    @State private var model: ClassRosterModel
    @State private var isShowingClassActions = false
    @State private var cacheStatusMessage: String?

    init(
        session: AuthSession,
        classContext: ClassContext,
        selectedClass: MBClass?,
        selectedContextTitle: String,
        selectedContextSubtitle: String,
        canShowClassSwitcher: Bool,
        classesService: ClassesService,
        faceEnrollmentStore: FaceEnrollmentStore,
        onShowClassSwitcher: @escaping () -> Void,
        onSignOut: @escaping () -> Void,
        onCaptureImage: @escaping ([ClassRosterStudent]) -> Void,
        onCaptureObservation: @escaping (ObservationCaptureLaunchContext) -> Void,
        onClearCache: @escaping () async -> Void,
        onTapStudent: @escaping (ClassRosterStudent) -> Void
    ) {
        self.session = session
        self.classContext = classContext
        self.selectedClass = selectedClass
        self.selectedContextTitle = selectedContextTitle
        self.selectedContextSubtitle = selectedContextSubtitle
        self.canShowClassSwitcher = canShowClassSwitcher
        self.classesService = classesService
        self.faceEnrollmentStore = faceEnrollmentStore
        self.onShowClassSwitcher = onShowClassSwitcher
        self.onSignOut = onSignOut
        self.onCaptureImage = onCaptureImage
        self.onCaptureObservation = onCaptureObservation
        self.onClearCache = onClearCache
        self.onTapStudent = onTapStudent
        _model = State(
            initialValue: ClassRosterModel(
                session: session,
                classesService: classesService,
                faceEnrollmentStore: faceEnrollmentStore
            )
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "#FBF6EE")
                .ignoresSafeArea()

            if classContext == .allClasses {
                chooseClassStateView
            } else if model.isLoading {
                ProgressView("Loading class roster…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = model.errorMessage {
                ContentUnavailableView(
                    "Unable to load this class",
                    systemImage: "person.3.slash",
                    description: Text(errorMessage)
                )
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    classRosterHeader
                    if let localStatusErrorMessage = model.localStatusErrorMessage {
                        Text(localStatusErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 24)
                            .padding(.top, 10)
                    }
                    if let cacheStatusMessage {
                        Text(cacheStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(Color(hex: "#6E6456"))
                            .padding(.horizontal, 24)
                            .padding(.top, 2)
                    }

                    if model.isSearchEmpty {
                        ContentUnavailableView(
                            "No matching students",
                            systemImage: "person.fill.questionmark",
                            description: Text("Try a different name.")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if model.students.isEmpty {
                        ContentUnavailableView(
                            "No children in this class",
                            systemImage: "person.3",
                            description: Text("This class does not expose any students right now.")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        classContent
                    }
                }
            }
        }
        .task(id: selectedClass?.id) {
            await model.loadIfNeeded(for: selectedClass, classContext: classContext)
        }
    }

    private var chooseClassStateView: some View {
        VStack(spacing: 14) {
            ClassPageTitleHeader(
                title: "Class",
                classTitle: "Choose a class",
                canShowClassSwitcher: canShowClassSwitcher,
                onShowClassSwitcher: onShowClassSwitcher
            )
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Image(systemName: "person.3")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)

            Text("Choose a class")
                .font(.title3.weight(.semibold))
                .padding(.top, 6)

            Text("Face setup is tracked per class on this device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var classRosterHeader: some View {
        VStack(spacing: 0) {
            ClassPageTitleHeader(
                title: "Class",
                classTitle: classPickerTitle,
                canShowClassSwitcher: canShowClassSwitcher,
                onShowClassSwitcher: onShowClassSwitcher,
                secondarySystemImage: "gearshape.fill",
                secondaryAccessibilityLabel: "Class options",
                onSecondaryAction: {
                    isShowingClassActions = true
                }
            )
            .confirmationDialog("Class options", isPresented: $isShowingClassActions, titleVisibility: .visible) {
                if classContext != .allClasses,
                   model.students.isEmpty == false,
                   model.isLoading == false {
                    Button("Capture image") {
                        onCaptureImage(model.students)
                    }
                }

                if let observationLaunchContext, model.isLoading == false {
                    Button("Capture observation") {
                        onCaptureObservation(observationLaunchContext)
                    }
                }

                Button("Clear cache") {
                    Task {
                        cacheStatusMessage = "Clearing local cache…"
                        await onClearCache()
                        cacheStatusMessage = "Local cache cleared."
                        try? await Task.sleep(nanoseconds: 2200_000_000)
                        cacheStatusMessage = nil
                    }
                }

                Button("Log Out", role: .destructive, action: onSignOut)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 10)

            searchBar

            if case .schoolClass = classContext {
                HStack(spacing: 6) {
                    Text("In today")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color(hex: "#3A342E"))
                    if model.presentStudents.isEmpty == false {
                        Text("· \(model.presentStudents.count) present")
                            .font(.subheadline)
                            .foregroundStyle(Color(hex: "#6E6456"))
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 10)
            }
        }
        .padding(.bottom, 4)
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

    private var classContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            LazyVGrid(
                columns: [
                    GridItem(.fixed(106), spacing: 12),
                    GridItem(.fixed(106), spacing: 12),
                    GridItem(.fixed(106), spacing: 12)
                ],
                alignment: .center,
                spacing: 12
            ) {
                ForEach(model.filteredStudents) { student in
                    ClassRosterTileView(student: student) {
                        onTapStudent(student)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 8)

            if !model.notInTodayStudents.isEmpty {
                HStack {
                    Text("Not in today")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color(hex: "#3A342E"))
                    Text("· \(model.notInTodayStudents.count) absent")
                        .font(.footnote)
                        .foregroundStyle(Color(hex: "#D99B8F"))
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)

                LazyVGrid(
                    columns: [
                        GridItem(.fixed(106), spacing: 12),
                        GridItem(.fixed(106), spacing: 12),
                        GridItem(.fixed(106), spacing: 12)
                    ],
                    alignment: .center,
                    spacing: 12
                ) {
                    ForEach(model.notInTodayStudents) { student in
                        ClassRosterTileView(student: student) {
                            onTapStudent(student)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color(hex: "#8DA67A"))
            TextField("Search names", text: Binding(
                get: { model.searchText },
                set: { model.setSearchText($0) }
            ))
                .textInputAutocapitalization(.none)
                .autocorrectionDisabled()
                .accessibilityLabel("Search names")
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 44)
        .background(Color(hex: "#FFFDF8"))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color(hex: "#E6D8C2"), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    private var classPickerTitle: String {
        if selectedContextTitle.isEmpty == false {
            return selectedContextTitle
        }
        return "Class"
    }

    private var observationLaunchContext: ObservationCaptureLaunchContext? {
        guard case .schoolClass(let classID) = classContext, let selectedClass, selectedClass.id == classID else {
            return nil
        }

        let className = selectedContextTitle.isEmpty ? selectedClass.displayName : selectedContextTitle
        guard className.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return nil
        }

        return ObservationCaptureLaunchContext(
            classID: classID,
            className: className,
            selectedClass: selectedClass,
            rosterSnapshot: model.students.map(ObservationRosterStudent.init)
        )
    }
}

struct ClassRosterTileView: View {
    let student: ClassRosterStudent
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 8) {
                    StudentAvatarView(
                        name: student.displayName,
                        initials: student.initials,
                        avatarURL: student.avatarURL
                    )
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Text(student.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(studentColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    HStack(spacing: 4) {
                        Circle()
                            .fill(presenceColor)
                            .frame(width: 6, height: 6)

                        if student.needsFaceEnrollment {
                            Text("Setup")
                                .font(.footnote)
                                .foregroundStyle(Color(hex: "#6E6456"))
                                .lineLimit(1)
                        } else {
                            Text(student.observationCountText)
                                .font(.footnote)
                                .foregroundStyle(Color(hex: "#6E6456"))
                        }
                    }
                }
                .frame(width: 106, height: 128)
                .padding(.top, 6)

                if student.needsFaceEnrollment {
                    Text("?")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(Color(hex: "#3A342E"))
                        .frame(width: 24, height: 24)
                        .background(Color(hex: "#E6B469"))
                        .clipShape(Circle())
                        .padding(8)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: 106, height: 128)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "#FFFDF8"))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: "#F5EDE0"), lineWidth: 0.8)
        )
        .opacity(student.presence == .notInToday ? 0.55 : 1.0)
        .accessibilityLabel(student.accessibilityLabel)
    }

    private var presenceColor: Color {
        student.presence == .present ? Color(hex: "#8DA67A") : Color(hex: "#D99B8F")
    }

    private var studentColor: Color {
        if student.needsFaceEnrollment {
            return Color(hex: "#6E6456")
        }
        if student.presence == .notInToday {
            return Color(hex: "#A89E8F")
        }
        return Color(hex: "#3A342E")
    }
}

struct StudentAvatarView: View {
    let name: String
    let initials: String
    let avatarURL: URL?

    var body: some View {
        if let avatarURL {
            AsyncImage(url: avatarURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    placeholder
                @unknown default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#F5EDE0"))
            Text(initials.isEmpty ? String(name.prefix(2)) : initials)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(hex: "#3A342E"))
        }
    }
}
