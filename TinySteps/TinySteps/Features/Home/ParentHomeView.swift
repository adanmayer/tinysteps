import SwiftUI
import MBAPI

struct ParentHomeView: View {
    @State private var attendanceExcusalModel: HomeAttendanceExcusalModel
    @State private var isAttendanceExcusalSheetPresented = false
    @State private var submitSuccessMessage: String?

    let session: AuthSession
    let childContext: ChildContext
    let selectedContextTitle: String
    let selectedContextSubtitle: String
    let canShowChildSwitcher: Bool
    let onShowChildSwitcher: () -> Void
    let onSignOut: () -> Void
    let parentAssociationService: ParentAssociationService

    init(
        session: AuthSession,
        childContext: ChildContext,
        selectedContextTitle: String,
        selectedContextSubtitle: String,
        canShowChildSwitcher: Bool,
        onShowChildSwitcher: @escaping () -> Void,
        onSignOut: @escaping () -> Void,
        parentAssociationService: ParentAssociationService
    ) {
        self.session = session
        self.childContext = childContext
        self.selectedContextTitle = selectedContextTitle
        self.selectedContextSubtitle = selectedContextSubtitle
        self.canShowChildSwitcher = canShowChildSwitcher
        self.onShowChildSwitcher = onShowChildSwitcher
        self.onSignOut = onSignOut
        self.parentAssociationService = parentAssociationService
        self._attendanceExcusalModel = State(
            initialValue: HomeAttendanceExcusalModel(
                session: session,
                parentAssociationService: parentAssociationService
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Signed in to \(session.schoolHost.displayName)")
                .foregroundStyle(.secondary)

            if let accountIdentifier = session.accountIdentifier {
                Text(accountIdentifier)
                    .font(.headline)
            }

            Button(action: onShowChildSwitcher) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedContextTitle)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(selectedContextSubtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if canShowChildSwitcher {
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(!canShowChildSwitcher)
            .accessibilityLabel("Switch child")

            attendanceExcusalButton

            VStack(alignment: .leading, spacing: 8) {
                Label("Notices placeholder", systemImage: "bell.badge")
                Label("Schedule placeholder", systemImage: "calendar")
                Label("Messages placeholder", systemImage: "message")
            }
            .errorMessage(
                attendanceExcusalModel.errorMessage,
                font: .caption,
                color: .orange,
                horizontalPadding: 0,
                topPadding: 8
            )
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Button("Sign Out", role: .destructive, action: onSignOut)
                .buttonStyle(.bordered)

            Spacer()
        }
        .task {
            await attendanceExcusalModel.loadIfNeeded()
        }
        .sheet(isPresented: $isAttendanceExcusalSheetPresented) {
            AttendanceExcusalSubmissionSheet(
                model: attendanceExcusalModel,
                isPresented: $isAttendanceExcusalSheetPresented,
                childContext: childContext
            )
        }
        .overlay(alignment: .top) {
            if let submitSuccessMessage {
                VStack {
                    Text(submitSuccessMessage)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(.green)
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 12)
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
        }
        .onChange(of: attendanceExcusalModel.didSubmitAttendanceExcusal) { _, didSubmit in
            guard didSubmit else {
                return
            }
            submitSuccessMessage = "Attendance excusal submitted successfully."
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.2))
                attendanceExcusalModel.prepareForNewSubmission()
                submitSuccessMessage = nil
            }
        }
        .onChange(of: isAttendanceExcusalSheetPresented) { _, isPresented in
            if isPresented {
                submitSuccessMessage = nil
                attendanceExcusalModel.prepareForNewSubmission()
            }
        }
        .padding(24)
    }

    @ViewBuilder
    private var attendanceExcusalButton: some View {
        if attendanceExcusalModel.isLoading {
            ProgressView("Loading attendance excusal…")
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if attendanceExcusalModel.isAttendanceExcusalEnabled {
            Button(action: {
                attendanceExcusalModel.prepareForNewSubmission()
                isAttendanceExcusalSheetPresented = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title3)
                        .foregroundStyle(.orange)
                        .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Attendance Excusal")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text("Submit an attendance excusal for a child.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if attendanceExcusalModel.isSubmitting {
                        ProgressView()
                            .padding(.trailing, 2)
                    }

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Submit attendance excusal")
            .disabled(attendanceExcusalModel.isSubmitting)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title3)
                        .foregroundStyle(.orange)
                        .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Attendance Excusal")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Text("No attendance excusal endpoint is available for this profile.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.quaternary)
                )
            }
        }
    }
}

#Preview {
    ParentHomeView(
        session: .preview,
        childContext: .allChildren,
        selectedContextTitle: "All Children",
        selectedContextSubtitle: "2 children",
        canShowChildSwitcher: true,
        onShowChildSwitcher: {},
        onSignOut: {},
        parentAssociationService: MBParentAssociationService.preview()
    )
}
