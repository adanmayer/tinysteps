import SwiftUI
import UIKit
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
    let onCaptureChildVoice: ([ClassRosterStudent]) -> Void
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
        onCaptureChildVoice: @escaping ([ClassRosterStudent]) -> Void,
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
        self.onCaptureChildVoice = onCaptureChildVoice
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
        .overlay(alignment: .bottomTrailing) {
            if shouldShowCaptureMenu {
                captureMenuButton
                    .padding(.trailing, 22)
                    .padding(.bottom, 28)
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
                Button("Clear cache") {
                    Task {
                        cacheStatusMessage = "Clearing local cache…"
                        StudentAvatarImageCache.shared.removeAll()
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

    private var captureMenuButton: some View {
        Menu {
            Button {
                if let observationLaunchContext {
                    onCaptureObservation(observationLaunchContext)
                }
            } label: {
                Label("Observation", systemImage: "mic.fill")
            }
            .disabled(observationLaunchContext == nil || model.isLoading)

            Button {
                onCaptureImage(model.students)
            } label: {
                Label("Image", systemImage: "camera.fill")
            }
            .disabled(canLaunchRosterCapture == false)

            Button {
                onCaptureChildVoice(model.students)
            } label: {
                Label("Child voice", systemImage: "waveform.circle.fill")
            }
            .disabled(canLaunchRosterCapture == false)
        } label: {
            ZStack {
                Circle()
                    .fill(Color(hex: "#6F9258"))
                    .frame(width: 64, height: 64)
                    .shadow(color: Color(hex: "#6F9258").opacity(0.34), radius: 18, x: 0, y: 10)

                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .overlay(
                Circle()
                    .stroke(Color(hex: "#FFFDF8").opacity(0.92), lineWidth: 3)
            )
        }
        .accessibilityLabel("Capture")
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

    private var shouldShowCaptureMenu: Bool {
        classContext != .allClasses
            && model.isLoading == false
            && model.errorMessage == nil
            && model.students.isEmpty == false
    }

    private var canLaunchRosterCapture: Bool {
        classContext != .allClasses
            && model.isLoading == false
            && model.students.isEmpty == false
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
            ZStack(alignment: .top) {
                VStack(spacing: 8) {
                    StudentAvatarView(
                        name: student.displayName,
                        initials: student.initials,
                        avatarURL: student.avatarURL,
                        cacheKey: student.userID ?? student.studentKey
                    )
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.14), radius: 8, x: 0, y: 4)
                    .overlay(alignment: .bottomTrailing) {
                        faceSetupIndicator
                            .offset(x: 3, y: 3)
                    }

                    Text(student.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(studentColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, 4)
                        .minimumScaleFactor(0.7)

                    presenceIndicator
                }
                .frame(width: 106, height: 128, alignment: .top)
                .padding(.top, 14)
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

    private var presenceIndicator: some View {
        Circle()
            .fill(presenceColor)
            .frame(width: 10, height: 10)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.75), lineWidth: 1)
            )
            .shadow(color: presenceColor.opacity(0.32), radius: 4, x: 0, y: 2)
    }

    private var faceSetupIndicator: some View {
        Group {
            if student.isFaceEnrolled {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(hex: "#5F7F52"))
                    .background(
                        Circle()
                            .fill(Color(hex: "#FFFDF8"))
                    )
            }
        }
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
    let cacheKey: String

    @State private var loadedImage: UIImage?
    @State private var loadedImageKey: String?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let loadedImage, loadedImageKey == avatarCacheKey {
                Image(uiImage: loadedImage)
                    .resizable()
                    .scaledToFill()
            } else if isLoading {
                placeholder
                    .overlay {
                        ProgressView()
                            .controlSize(.mini)
                    }
            } else {
                placeholder
            }
        }
        .task(id: avatarCacheKey) {
            await loadAvatar()
        }
    }

    private var avatarCacheKey: String? {
        guard let avatarURL else {
            return nil
        }

        let trimmedCacheKey = cacheKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let stableIdentity = trimmedCacheKey.isEmpty ? name : trimmedCacheKey
        return "\(stableIdentity)|\(avatarURL.host ?? "")|\(avatarURL.path)"
    }

    @MainActor
    private func loadAvatar() async {
        guard let avatarURL, let avatarCacheKey else {
            loadedImage = nil
            loadedImageKey = nil
            isLoading = false
            return
        }

        if loadedImageKey != avatarCacheKey {
            loadedImage = nil
            loadedImageKey = nil
        }

        if let cachedImage = StudentAvatarImageCache.shared.image(forKey: avatarCacheKey) {
            loadedImage = cachedImage
            loadedImageKey = avatarCacheKey
            isLoading = false
            return
        }

        isLoading = true
        defer {
            isLoading = false
        }

        do {
            let request = URLRequest(url: avatarURL, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard Task.isCancelled == false else {
                return
            }

            if let httpResponse = response as? HTTPURLResponse,
               (200..<300).contains(httpResponse.statusCode) == false {
                return
            }

            guard let image = UIImage(data: data) else {
                return
            }

            StudentAvatarImageCache.shared.set(image, forKey: avatarCacheKey)
            loadedImage = image
            loadedImageKey = avatarCacheKey
        } catch {
            loadedImage = nil
            loadedImageKey = nil
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

private final class StudentAvatarImageCache: @unchecked Sendable {
    static let shared = StudentAvatarImageCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 240
        cache.totalCostLimit = 24 * 1024 * 1024
    }

    func image(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func set(_ image: UIImage, forKey key: String) {
        let cost = image.pngData()?.count ?? 1
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }

    func removeAll() {
        cache.removeAllObjects()
    }
}
