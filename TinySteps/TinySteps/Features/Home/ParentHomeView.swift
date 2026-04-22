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
    let availableChildren: [MBChild]
    let portfolioService: PortfolioService
    let classesService: ClassesService
    let onShowChildSwitcher: () -> Void
    let onSignOut: () -> Void
    let parentAssociationService: ParentAssociationService

    init(
        session: AuthSession,
        childContext: ChildContext,
        selectedContextTitle: String,
        selectedContextSubtitle: String,
        canShowChildSwitcher: Bool,
        availableChildren: [MBChild],
        portfolioService: PortfolioService,
        classesService: ClassesService,
        onShowChildSwitcher: @escaping () -> Void,
        onSignOut: @escaping () -> Void,
        parentAssociationService: ParentAssociationService
    ) {
        self.session = session
        self.childContext = childContext
        self.selectedContextTitle = selectedContextTitle
        self.selectedContextSubtitle = selectedContextSubtitle
        self.canShowChildSwitcher = canShowChildSwitcher
        self.availableChildren = availableChildren
        self.portfolioService = portfolioService
        self.classesService = classesService
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
        PortfolioTimelineView(
            session: session,
            childContext: childContext,
            selectedScopeTitle: selectedContextTitle,
            selectedScopeSubtitle: selectedContextSubtitle,
            canShowScopeSwitcher: canShowChildSwitcher,
            availableChildren: availableChildren,
            portfolioService: portfolioService,
            classesService: classesService,
            onShowScopeSwitcher: onShowChildSwitcher
        )
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
        .safeAreaInset(edge: .bottom) {
            attendanceExcusalFooter
        }
    }

    @ViewBuilder
    private var attendanceExcusalFooter: some View {
        if attendanceExcusalModel.isLoading {
            EmptyView()
        } else if attendanceExcusalModel.isAttendanceExcusalEnabled {
            Button(action: {
                attendanceExcusalModel.prepareForNewSubmission()
                isAttendanceExcusalSheetPresented = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                        .frame(width: 30, height: 30)
                        .background(Color(hex: "#F5EDE0"))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Attendance Excusal")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text("Submit an excusal for \(selectedContextTitle).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
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
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "#FFFDF8").opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color(hex: "#E6D8C2"), lineWidth: 0.6)
                )
                .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Submit attendance excusal")
            .disabled(attendanceExcusalModel.isSubmitting)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(Color(hex: "#FBF6EE").opacity(0.92))
            .errorMessage(
                attendanceExcusalModel.errorMessage,
                font: .caption,
                color: .orange,
                horizontalPadding: 20,
                topPadding: 6
            )
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
        availableChildren: MBChild.previewChildren,
        portfolioService: MBPortfolioService.preview(),
        classesService: MBClassesService.preview(),
        onShowChildSwitcher: {},
        onSignOut: {},
        parentAssociationService: MBParentAssociationService.preview()
    )
}
