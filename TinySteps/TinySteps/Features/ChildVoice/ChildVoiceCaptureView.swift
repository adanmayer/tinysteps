import SwiftUI

struct ChildVoiceCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ChildVoiceCaptureViewModel
    private let onSaved: (ChildVoiceDraft) -> Void
    private let modeTitle: String

    init(
        session: ChildVoiceCaptureSession,
        onSaved: @escaping (ChildVoiceDraft) -> Void = { _ in }
    ) {
        _viewModel = StateObject(
            wrappedValue: ChildVoiceCaptureViewModel(session: session)
        )
        self.onSaved = onSaved
        switch session.mode {
        case .photoAttachment:
            modeTitle = "Photo voice"
        case .standaloneNote:
            modeTitle = "Child voice"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                headerRow

                VStack(spacing: 26) {
                    Text(modeTitle)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color(hex: "#3A342E"))

                    Text("Capture a short voice note for \(viewModel.childName).")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color(hex: "#6D6355"))
                        .padding(.horizontal, 16)

                    stateContent

                    if case .failed(let message) = viewModel.state {
                        Text(message)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color(hex: "#B94A3C"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 18)
                    }
                }
                .frame(maxHeight: .infinity)

                actionRow
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 12)
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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        viewModel.cancel()
                        dismiss()
                    }
                    .foregroundStyle(Color(hex: "#3A342E"))
                }
            }
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color(hex: "#8DA67A"), lineWidth: 2)
                    .frame(width: 170, height: 170)
                    .opacity(viewModel.state == .ready || viewModel.state == .recording ? 1 : 0.45)

                if case .recording = viewModel.state {
                    PulseCircle()
                }

                Image(systemName: iconName)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 90, height: 90)
                    .background(
                        Circle()
                            .fill(iconBackground)
                    )
            }
            .frame(height: 190)

            Text(viewModel.recordingTimeText)
                .font(.system(.title2, design: .monospaced))
                .foregroundStyle(Color(hex: "#3A342E"))
                .padding(.vertical, 4)

            if case .recorded = viewModel.state {
                Button {
                    viewModel.togglePlayback()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 22, weight: .semibold))
                        Text(viewModel.isPlaying ? "Pause" : "Play")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hex: "#3A342E"))
                    .frame(height: 40)
                    .frame(maxWidth: .infinity)
                    .background(Color(hex: "#F0E8D7"))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        VStack(spacing: 12) {
            switch viewModel.state {
            case .askingAssent:
                Button("Tap here if \(viewModel.childName) said yes") {
                    Task {
                        await viewModel.begin()
                    }
                }
                .buttonStyle(.borderedProminent)
            case .ready:
                Button("Start recording") {
                    viewModel.startRecording()
                }
                .buttonStyle(.borderedProminent)
            case .recording:
                Button("Stop") {
                    viewModel.stopRecording()
                }
                .buttonStyle(.borderedProminent)
            case .recorded:
                HStack(spacing: 12) {
                    Button("Rerecord") {
                        viewModel.rerecord()
                    }
                    .buttonStyle(.bordered)

                    Button("Discard") {
                        viewModel.discardRecording()
                    }
                    .buttonStyle(.bordered)

                    Button("Save") {
                        viewModel.saveDraft()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.state != .recorded)
                }
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
        .padding(.bottom, 6)
    }

    private var iconName: String {
        switch viewModel.state {
        case .recording:
            "mic.fill"
        case .ready, .askingAssent, .recorded, .saved, .savingLocalDraft, .failed:
            "mic"
        }
    }

    private var iconColor: Color {
        switch viewModel.state {
        case .recording:
            .red
        case .ready, .askingAssent, .recorded, .saved, .savingLocalDraft, .failed:
            Color(hex: "#3A342E")
        }
    }

    private var iconBackground: Color {
        switch viewModel.state {
        case .recording:
            Color(hex: "#FFE5E6")
        case .ready, .askingAssent, .recorded, .saved, .savingLocalDraft, .failed:
            Color(hex: "#F3ECDC")
        }
    }

    private var headerRow: some View {
        HStack {
            Text("Child Voice")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color(hex: "#3A342E"))
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

}

private struct PulseCircle: View {
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.8

    var body: some View {
        Circle()
            .stroke(Color(hex: "#FFB6B6").opacity(opacity), lineWidth: 2)
            .frame(width: 170, height: 170)
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
