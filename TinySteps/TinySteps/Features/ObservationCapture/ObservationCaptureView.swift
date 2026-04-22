import SwiftUI
import UIKit

struct ObservationCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var model: ObservationCaptureViewModel
    @State private var isShowingDiscardConfirmation = false
    @State private var isShowingStudentPicker = false
    @State private var selectedEvidence: ObservationEvidenceSpan?
    @State private var pulse = false

    private let onDismiss: () -> Void
    private let session: AuthSession

    init(
        captureSession: ObservationCaptureSession,
        speechTranscriber: ObservationSpeechTranscribing,
        taggingService: ObservationTaggingService,
        standardsLoadingService: MBStandardsLoadingService,
        childMatcher: ObservationChildNameMatching,
        draftStore: ObservationCaptureDraftStore,
        session: AuthSession,
        onDismiss: @escaping () -> Void
    ) {
        _model = State(
            initialValue: ObservationCaptureViewModel(
                captureSession: captureSession,
                speechTranscriber: speechTranscriber,
                taggingService: taggingService,
                standardsLoadingService: standardsLoadingService,
                childMatcher: childMatcher,
                draftStore: draftStore,
                session: session
            )
        )
        self.session = session
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            Color(hex: "#FBF6EE")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: 26) {
                        transcriptCard
                        chipBloomSection
                        detectedChildrenSection
                        evidenceSection
                        stateMessageSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }

                microphoneBar
            }
        }
        .task {
            await model.prepare()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase != .active else {
                return
            }

            Task {
                await model.cancelActiveCapture()
            }
        }
        .onDisappear {
            Task {
                await model.cancelActiveCapture()
            }
        }
        .sheet(isPresented: $isShowingStudentPicker) {
            ObservationStudentPickerSheet(
                students: model.rosterStudents,
                selectedStudentKeys: model.selectedStudentKeys
            ) { student in
                withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                    model.addMatchedChild(studentID: student.id)
                }
            }
        }
        .confirmationDialog(
            "Keep this local observation draft?",
            isPresented: $isShowingDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Save") {
                Task {
                    if await model.saveDraft() {
                        close()
                    }
                }
            }
            .disabled(!model.canSave)

            Button("Discard draft", role: .destructive) {
                Task {
                    await model.discardDraft()
                    close()
                }
            }

            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("Your transcript has not been published or synced.")
        }
    }

    private var header: some View {
        ZStack {
            Text("Observation")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color(hex: "#3A342E"))
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            HStack {
                Button(action: requestClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: "#3A342E"))
                        .frame(width: 36, height: 36)
                        .background(Color(hex: "#FFFDF8"))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color(hex: "#E6D8C2"), lineWidth: 1)
                        )
                }
                .accessibilityLabel("Close observation capture")

                Spacer()

                saveButton
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var microphoneHero: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color(hex: "#8DA67A").opacity(model.isRecording ? 0.22 : 0.12), lineWidth: 1)
                    .frame(width: 128, height: 128)
                    .scaleEffect(model.isRecording && pulse ? 1.14 : 1)
                    .opacity(model.isRecording && pulse ? 0.25 : 1)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#8DA67A"),
                                Color(hex: "#6B8659")
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 96, height: 96)
                    .shadow(color: Color(hex: "#6E6456").opacity(0.24), radius: 20, x: 0, y: 10)

                Image(systemName: model.isRecording ? "waveform" : "mic.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if model.isMicControlActive == false {
                            playRecordStartFeedback()
                        }
                        model.beginMicPress()
                    }
                    .onEnded { _ in
                        model.endMicPress()
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(model.isMicControlActive ? "Stop recording observation" : "Start recording observation")
            .accessibilityValue(model.isRecording ? "Recording" : "Not recording")
            .accessibilityHint(model.isMicControlActive ? "Double-tap to stop recording." : "Double-tap to start recording. Press and hold also works.")
            .accessibilityAction {
                toggleMicRecordingFromAccessibility()
            }
            .accessibilityAction(named: Text(model.isMicControlActive ? "Stop recording" : "Start recording")) {
                toggleMicRecordingFromAccessibility()
            }
            .onChange(of: model.isRecording) { _, isRecording in
                withAnimation(
                    isRecording
                    ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                    : .default
                ) {
                    pulse = isRecording
                }

                announceRecordingState(isRecording)
            }

            Text("Press and hold to record observation")
                .font(.subheadline)
                .foregroundStyle(Color(hex: "#6E6456"))
        }
    }

    private var transcriptCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(hex: "#FFFDF8"))
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)

            TextEditor(
                text: Binding(
                    get: { model.transcript },
                    set: { model.updateTranscript($0) }
                )
            )
            .font(.body)
            .foregroundStyle(Color(hex: "#3A342E"))
            .scrollContentBackground(.hidden)
            .padding(12)
            .frame(minHeight: 148)
            .accessibilityLabel("Observation transcript")

            if model.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Your words will appear here...")
                    .font(.body.italic())
                    .foregroundStyle(Color(hex: "#A89E8F"))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 20)
                    .allowsHitTesting(false)
            }

            if model.isRecording {
                VStack(spacing: 10) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Color(hex: "#D99B8F"))

                    Text("Describe your observation")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(hex: "#3A342E"))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: "#FFFDF8").opacity(0.86))
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 148)
    }

    private var chipBloomSection: some View {
        VStack(spacing: 10) {
            Text("Chips bloom when you speak")
                .font(.caption)
                .foregroundStyle(Color(hex: "#6E6456"))

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: chipColumnMinimum), spacing: 8)],
                spacing: 8
            ) {
                tagGroup(category: .transdisciplinaryTheme, values: themeValues)
                tagGroup(category: .keyConcept, values: conceptValues)
                tagGroup(category: .atlSkill, values: atlValues)
                tagGroup(category: .learnerProfile, values: profileValues)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Suggested PYP tags")
    }

    @ViewBuilder
    private func tagGroup(category: ObservationPYPTagCategory, values: [String]) -> some View {
        if model.isRecording || model.isSuggestingTags || values.isEmpty {
            ObservationTagChip(
                text: "\(category.displayTitle): -",
                isSkeleton: true,
                onTap: nil,
                onRemove: nil
            )
            .opacity(model.isRecording || model.isSuggestingTags ? 0.35 : 0.28)
        } else {
            ForEach(values, id: \.self) { value in
                ObservationTagChip(
                    text: "\(category.displayTitle): \(value)",
                    isSkeleton: false,
                    onTap: {
                        selectedEvidence = model.evidence(for: category, value: value)
                    },
                    onRemove: {
                        if selectedEvidence?.category == category && selectedEvidence?.value == value {
                            selectedEvidence = nil
                        }
                        model.removeTag(category: category, value: value)
                    }
                )
            }
        }
    }

    private var detectedChildrenSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Students")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hex: "#3A342E"))

                Button {
                    isShowingStudentPicker = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: "#3A342E"))
                        .frame(width: 26, height: 26)
                        .background(Color(hex: "#FFFDF8"))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color(hex: "#E6D8C2"), lineWidth: 1)
                        )
                }
                .disabled(model.rosterStudents.isEmpty)
                .accessibilityLabel("Assign student manually")

                Spacer()
            }

            if model.matchedChildren.isEmpty {
                Text("No students assigned yet.")
                    .font(.caption)
                    .foregroundStyle(Color(hex: "#A89E8F"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: chipColumnMinimum), spacing: 8, alignment: .leading)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(model.matchedChildren) { child in
                        HStack(spacing: 6) {
                            Text(child.displayName)
                                .font(.caption.weight(.medium))
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)

                            Button {
                                withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                                    model.removeMatchedChild(id: child.id)
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                            }
                            .accessibilityLabel("Remove \(child.displayName)")
                        }
                        .foregroundStyle(Color(hex: "#3A342E"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .frame(minHeight: 30)
                        .background(Color(hex: "#E6B469").opacity(0.18))
                        .clipShape(Capsule())
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.88).combined(with: .opacity),
                                removal: .scale(scale: 0.94).combined(with: .opacity)
                            )
                        )
                    }
                }
                .animation(.spring(response: 0.34, dampingFraction: 0.82), value: model.matchedChildren)
                .accessibilityLabel("Students")
            }
        }
        .animation(.easeInOut(duration: 0.18), value: model.matchedChildren.isEmpty)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var evidenceSection: some View {
        if let selectedEvidence {
            VStack(alignment: .leading, spacing: 8) {
                Text("Evidence")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(hex: "#6E6456"))

                Text(selectedEvidence.quote)
                    .font(.footnote)
                    .foregroundStyle(Color(hex: "#3A342E"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "#FFFDF8"))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "#E6D8C2"), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private var stateMessageSection: some View {
        if let errorMessage = model.errorMessage {
            VStack(alignment: .leading, spacing: 10) {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(Color(hex: "#D99B8F"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(errorMessage)

                if model.shouldRetryStandardsLoad {
                    Button("Retry standards") {
                        Task {
                            await model.retryLoadStandards()
                        }
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(hex: "#6B8659"))
                }
            }
        } else if let statusMessage = model.statusMessage {
            Text(statusMessage)
                .font(.footnote)
                .foregroundStyle(Color(hex: "#6E6456"))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var microphoneBar: some View {
        microphoneHero
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background(Color(hex: "#FBF6EE").opacity(0.96))
    }

    private var saveButton: some View {
        Button(model.isSaving ? "Saving..." : "Save") {
            Task {
                if await model.saveDraft() {
                    close()
                }
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(model.canSave ? .white : Color(hex: "#6E6456").opacity(0.65))
        .padding(.horizontal, 16)
        .frame(minWidth: 68, minHeight: 36)
        .background(
            Capsule()
                .fill(Color(hex: "#6B8659").opacity(model.canSave ? 1 : 0.24))
        )
        .overlay(
            Capsule()
                .stroke(model.canSave ? Color.clear : Color(hex: "#A89E8F").opacity(0.45), lineWidth: 1)
        )
        .disabled(!model.canSave)
        .accessibilityLabel("Save observation")
    }

    private var chipColumnMinimum: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 180 : 130
    }

    private var themeValues: [String] {
        tagsToStrings(model.tags.transdisciplinaryTheme.map { [$0] } ?? [])
    }

    private var conceptValues: [String] {
        tagsToStrings(model.tags.keyConcepts)
    }

    private var atlValues: [String] {
        tagsToStrings(model.tags.atlSkills)
    }

    private var profileValues: [String] {
        tagsToStrings(model.tags.learnerProfile)
    }

    private func tagsToStrings<T: RawRepresentable>(_ values: [T]) -> [String] where T.RawValue == String {
        values.map(\.rawValue)
    }

    private func requestClose() {
        Task {
            await model.cancelActiveCapture()
            if model.hasTranscript {
                isShowingDiscardConfirmation = true
            } else {
                close()
            }
        }
    }

    private func close() {
        onDismiss()
        dismiss()
    }

    private func toggleMicRecordingFromAccessibility() {
        if model.isMicControlActive {
            model.endMicPress()
        } else {
            playRecordStartFeedback()
            model.beginMicPress()
        }
    }

    private func playRecordStartFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    private func announceRecordingState(_ isRecording: Bool) {
        guard UIAccessibility.isVoiceOverRunning || UIAccessibility.isSwitchControlRunning else {
            return
        }

        UIAccessibility.post(
            notification: .announcement,
            argument: isRecording ? "Recording started" : "Recording stopped"
        )
    }
}

private struct ObservationStudentPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let students: [ObservationRosterStudent]
    let selectedStudentKeys: Set<String>
    let onSelect: (ObservationRosterStudent) -> Void

    var body: some View {
        NavigationStack {
            List(students) { student in
                Button {
                    onSelect(student)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Text(student.initials)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Color(hex: "#8DA67A"))
                            .clipShape(Circle())

                        Text(student.displayName)
                            .font(.body)
                            .foregroundStyle(Color(hex: "#3A342E"))

                        Spacer()

                        if selectedStudentKeys.contains(student.studentKey) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color(hex: "#8DA67A"))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(selectedStudentKeys.contains(student.studentKey))
                .accessibilityLabel(
                    selectedStudentKeys.contains(student.studentKey)
                    ? "\(student.displayName), already assigned"
                    : "Assign \(student.displayName)"
                )
            }
            .navigationTitle("Assign student")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct ObservationTagChip: View {
    let text: String
    let isSkeleton: Bool
    let onTap: (() -> Void)?
    let onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 6) {
            Button {
                onTap?()
            } label: {
                Text(text)
                    .font(.caption.weight(.medium))
                    .lineLimit(nil)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(.plain)
            .disabled(onTap == nil)

            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(text)")
            }
        }
        .foregroundStyle(Color(hex: "#3A342E"))
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .frame(minHeight: 30)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "#8DA67A").opacity(isSkeleton ? 0.10 : 0.18))
        .clipShape(Capsule())
        .accessibilityLabel(text)
    }
}

private struct ObservationPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(isEnabled ? .white : Color(hex: "#6E6456").opacity(0.65))
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .background(
                Color(hex: "#6B8659")
                    .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.24)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isEnabled ? Color.clear : Color(hex: "#A89E8F").opacity(0.45), lineWidth: 1)
            )
            .opacity(configuration.isPressed && isEnabled ? 0.88 : 1)
    }
}

private struct ObservationSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(Color(hex: "#6E6456").opacity(isEnabled ? 1 : 0.45))
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .background(Color(hex: "#FFFDF8").opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.55))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color(hex: "#E6D8C2").opacity(isEnabled ? 1 : 0.55), lineWidth: 1)
            )
    }
}

#if DEBUG
#Preview("Observation Capture") {
    ObservationCaptureView(
        captureSession: .preview,
        speechTranscriber: PreviewObservationSpeechTranscriber(
            scriptedTranscript: "Amara explained that the bridge needed to be stronger before Finn could drive across it."
        ),
        taggingService: DisabledObservationTaggingService(),
        standardsLoadingService: MBStandardsLoadingServiceImpl.preview(),
        childMatcher: LocalObservationChildNameMatcher(),
        draftStore: InMemoryObservationCaptureDraftStore(),
        session: .previewTeacher,
        onDismiss: {}
    )
}
#endif
