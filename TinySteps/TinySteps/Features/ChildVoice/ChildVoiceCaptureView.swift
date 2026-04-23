import SwiftUI

struct ChildVoiceCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ChildVoiceCaptureViewModel
    private let onSaved: (ChildVoiceDraft) -> Void

    init(
        session: ChildVoiceCaptureSession,
        onSaved: @escaping (ChildVoiceDraft) -> Void = { _ in }
    ) {
        _viewModel = StateObject(
            wrappedValue: ChildVoiceCaptureViewModel(session: session)
        )
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#F3ECDE")
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, 24)
                        .padding(.top, 12)

                    assentConfirmationCard
                        .padding(.horizontal, 24)
                        .padding(.top, 22)

                    Spacer(minLength: 18)

                    titleBlock
                        .padding(.horizontal, 28)

                    stateContent
                        .padding(.top, 20)
                        .padding(.horizontal, 22)

                    if case .failed(let message) = viewModel.state {
                        Text(message)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color(hex: "#B94A3C"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.top, 16)
                    }

                    Spacer(minLength: 28)

                    actionRow
                        .padding(.horizontal, 24)
                }
            }
            .onChange(of: viewModel.state) { _, newState in
                guard case .saved = newState, let draft = viewModel.savedDraft else {
                    return
                }
                onSaved(draft)
                dismiss()
            }
            .onDisappear {
                viewModel.cancelIfNeeded()
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        VStack(spacing: 18) {
            recordingControl

            Text(viewModel.recordingTimeText)
                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(hex: "#817669"))
                .padding(.top, 6)

            if case .recorded = viewModel.state {
                recordedControls
            }
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        VStack(spacing: 12) {
            switch viewModel.state {
            case .askingAssent:
                assentButton
            case .ready, .recording:
                captureActionButtons(canSave: false)
            case .recorded:
                captureActionButtons(canSave: true)
            case .savingLocalDraft:
                HStack {
                    ProgressView()
                        .tint(Color(hex: "#8DA67A"))
                    Text("Saving")
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: "#6D6355"))
                }
                .frame(height: 44)
            case .saved:
                EmptyView()
            case .failed:
                Button("Try again") {
                    viewModel.resetToReady()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .font(.subheadline.weight(.semibold))
        .padding(.bottom, 24)
    }

    private var recordingControl: some View {
        Button {
            Task {
                await viewModel.handlePrimaryRecordingControl()
            }
        } label: {
            ZStack {
                Circle()
                    .stroke(Color(hex: "#E7D5B9").opacity(0.54), lineWidth: 1)
                    .frame(width: 250, height: 250)

                Circle()
                    .stroke(controlRingColor.opacity(controlRingOpacity), lineWidth: 1)
                    .frame(width: 218, height: 218)
                    .scaleEffect(viewModel.state == .recording ? 1.08 : 1)

                if case .recording = viewModel.state {
                    PulseCircle()
                }

                Circle()
                    .fill(controlFill)
                    .frame(width: 128, height: 128)
                    .shadow(color: controlShadowColor, radius: 20, x: 0, y: 10)

                Image(systemName: controlIconName)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(height: 264)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isRecordingControlEnabled == false)
        .accessibilityLabel(recordingControlAccessibilityLabel)
        .accessibilityValue(recordingControlAccessibilityValue)
    }

    private var recordedControls: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.togglePlayback()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                    Text(viewModel.isPlaying ? "Pause" : "Play")
                }
                .frame(height: 42)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(hex: "#3A342E"))
            .background(Color(hex: "#F0E8D7"))
            .clipShape(Capsule())

            Button {
                viewModel.rerecord()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Rerecord")
                }
                .frame(height: 42)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(hex: "#3A342E"))
            .background(Color(hex: "#F5F0E7"))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color(hex: "#E1D7C6"), lineWidth: 1)
            )
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                viewModel.cancel()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color(hex: "#6D6355"))
                    .frame(width: 64, height: 64)
                    .background(Color(hex: "#FFFDF8"))
                    .clipShape(Circle())
                    .shadow(color: Color(hex: "#6E6456").opacity(0.12), radius: 18, x: 0, y: 8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close child voice capture")

            Spacer()
        }
    }

    private var assentConfirmationCard: some View {
        HStack(spacing: 18) {
            childAvatar

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(assentTitle)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(Color(hex: "#3A342E"))
                        .lineLimit(1)

                    if viewModel.didConfirmChildAssent {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 25, weight: .semibold))
                            .foregroundStyle(Color(hex: "#8DA67A"))
                    }
                }

                if viewModel.didConfirmChildAssent {
                    Text(assentSubtitle)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(Color(hex: "#6D6355"))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 32)
        .frame(height: 108)
        .background(Color(hex: "#FFFDF8"))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Color(hex: "#6E6456").opacity(0.08), radius: 22, x: 0, y: 12)
    }

    private var childAvatar: some View {
        ZStack {
            if let avatarURL = viewModel.childAvatarURL {
                AsyncImage(url: avatarURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        initialsAvatar
                    }
                }
            } else {
                initialsAvatar
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color(hex: "#8DA67A"), lineWidth: 1.2)
        )
    }

    private var initialsAvatar: some View {
        Circle()
            .fill(Color(hex: "#8DA67A"))
            .overlay(
                Text(viewModel.childInitials)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            )
    }

    private var titleBlock: some View {
        VStack(spacing: 18) {
            Text("In \(viewModel.childName)'s words")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color(hex: "#DDB15F"))
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text(instructionText)
                .font(.system(size: 23, weight: .regular))
                .foregroundStyle(Color(hex: "#6D6355"))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
        }
    }

    private var assentTitle: String {
        viewModel.didConfirmChildAssent ? "\(viewModel.childName) said yes" : "Ask \(viewModel.childName) first"
    }

    private var assentSubtitle: String {
        "Pass the phone to \(viewModel.childName)..."
    }

    private var instructionText: String {
        switch viewModel.state {
        case .askingAssent:
            return "Ask \(viewModel.childName) if they want to record"
        case .ready:
            return "Tap the microphone to begin"
        case .recording:
            return "Tap stop when \(viewModel.childName) is finished"
        case .recorded:
            return "Listen back or record again"
        case .savingLocalDraft:
            return "Saving..."
        case .saved:
            return "Saved"
        case .failed:
            return "Try again when you are ready"
        }
    }

    private var assentButton: some View {
        Button {
            Task {
                await viewModel.begin()
            }
        } label: {
            Text("\(viewModel.childName) said yes")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(height: 62)
                .frame(maxWidth: .infinity)
                .background(Color(hex: "#8DA67A"))
                .clipShape(Capsule())
                .shadow(color: Color(hex: "#6B8659").opacity(0.18), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    private func captureActionButtons(canSave: Bool) -> some View {
        HStack(spacing: 12) {
            Button {
                viewModel.cancel()
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: "#6D6355"))
                    .frame(height: 58)
                    .frame(maxWidth: .infinity)
                    .background(Color(hex: "#FFFDF8").opacity(0.7))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color(hex: "#E1D7C6"), lineWidth: 1.1)
                    )
            }
            .buttonStyle(.plain)

            saveButton(isEnabled: canSave)
        }
    }

    private func saveButton(isEnabled: Bool) -> some View {
        Button {
            viewModel.saveDraft()
        } label: {
            Text("Save")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isEnabled ? .white : Color(hex: "#6E6456").opacity(0.58))
                .frame(height: 58)
                .frame(maxWidth: .infinity)
                .background(Color(hex: "#8DA67A").opacity(isEnabled ? 1 : 0.24))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color(hex: "#8DA67A").opacity(isEnabled ? 0 : 0.42), lineWidth: 1.1)
                )
        }
        .buttonStyle(.plain)
        .disabled(isEnabled == false)
    }

    private var isRecordingControlEnabled: Bool {
        switch viewModel.state {
        case .ready, .recording:
            return true
        case .askingAssent, .recorded, .savingLocalDraft, .saved, .failed:
            return false
        }
    }

    private var controlIconName: String {
        switch viewModel.state {
        case .recording:
            return "stop.fill"
        case .recorded, .saved:
            return "checkmark"
        case .savingLocalDraft:
            return "hourglass"
        case .failed:
            return "exclamationmark"
        case .ready, .askingAssent:
            return "mic.fill"
        }
    }

    private var controlFill: LinearGradient {
        let colors: [Color]
        switch viewModel.state {
        case .recording:
            colors = [
                Color(hex: "#C85649"),
                Color(hex: "#A8382F")
            ]
        case .recorded, .saved:
            colors = [
                Color(hex: "#8DA67A"),
                Color(hex: "#6B8659")
            ]
        case .failed:
            colors = [
                Color(hex: "#B94A3C"),
                Color(hex: "#92352A")
            ]
        case .savingLocalDraft:
            colors = [
                Color(hex: "#A89E8F"),
                Color(hex: "#817669")
            ]
        case .ready, .askingAssent:
            colors = [
                Color(hex: "#8DA67A"),
                Color(hex: "#6B8659")
            ]
        }

        return LinearGradient(
            colors: colors,
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var controlRingColor: Color {
        switch viewModel.state {
        case .recording, .failed:
            return Color(hex: "#C85649")
        case .ready, .askingAssent, .recorded, .savingLocalDraft, .saved:
            return Color(hex: "#8DA67A")
        }
    }

    private var controlRingOpacity: Double {
        viewModel.state == .recording ? 0.28 : 0.14
    }

    private var controlShadowColor: Color {
        switch viewModel.state {
        case .recording, .failed:
            return Color(hex: "#8F3A31").opacity(0.24)
        case .ready, .askingAssent, .recorded, .savingLocalDraft, .saved:
            return Color(hex: "#6E6456").opacity(0.24)
        }
    }

    private var recordingControlAccessibilityLabel: String {
        switch viewModel.state {
        case .askingAssent:
            return "Start child voice recording after assent"
        case .ready:
            return "Start child voice recording"
        case .recording:
            return "Stop child voice recording"
        case .recorded:
            return "Child voice recording complete"
        case .savingLocalDraft:
            return "Saving child voice recording"
        case .saved:
            return "Child voice recording saved"
        case .failed:
            return "Child voice recording failed"
        }
    }

    private var recordingControlAccessibilityValue: String {
        switch viewModel.state {
        case .recording:
            return "Recording"
        case .recorded:
            return "Recorded"
        case .askingAssent, .ready, .savingLocalDraft, .saved, .failed:
            return "Not recording"
        }
    }

}

private struct PulseCircle: View {
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.8

    var body: some View {
        Circle()
            .stroke(Color(hex: "#FFB6B6").opacity(opacity), lineWidth: 2)
            .frame(width: 236, height: 236)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                    scale = 1.08
                    opacity = 0.24
                }
            }
    }
}

struct ChildVoiceCaptureView_Previews: PreviewProvider {
    static var previews: some View {
        ChildVoiceCaptureView(
            session: ChildVoiceCaptureSession(
                mode: .standaloneNote(
                    classID: "class-1",
                    className: "Grade 1",
                    child: .init(studentKey: "child-1", userID: "user-1", displayName: "Amara Quinn")
                )
            )
        )
    }
}
