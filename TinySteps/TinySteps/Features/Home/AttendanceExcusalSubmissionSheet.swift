import SwiftUI
import MBAPI
import Observation

struct AttendanceExcusalSubmissionSheet: View {
    @Bindable var model: HomeAttendanceExcusalModel
    @Binding var isPresented: Bool
    let childContext: ChildContext
    @FocusState private var isReasonFocused: Bool

    @State private var selectedDate: Date = .now
    @State private var selectedDuration: Int = 1
    @State private var reason = ""

    private let allowedDurations = Array(1...14)

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Form {
                    Section("Date") {
                        DatePicker(
                            "Start date",
                            selection: $selectedDate,
                            in: ...Date.distantFuture,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                    }

                    Section("Duration") {
                        Picker("Days", selection: $selectedDuration) {
                            ForEach(allowedDurations, id: \.self) { day in
                                Text("\(day) day\(day == 1 ? "" : "s")").tag(day)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Section("Reason") {
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $reason)
                                .frame(minHeight: 120)
                                .focused($isReasonFocused)

                            if reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Add a short reason")
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                }

                Spacer()

                HStack {
                    Button("Cancel", role: .cancel) {
                        isPresented = false
                    }
                    .frame(maxWidth: .infinity)

                    Button("Submit") {
                        Task {
                            let didSubmit = await model.submit(
                                for: childContext,
                                startDate: selectedDate,
                                duration: selectedDuration,
                                reason: reason
                            )
                            if didSubmit {
                                isPresented = false
                            }
                        }
                    }
                    .disabled(canSubmit == false || model.isSubmitting)
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .navigationTitle("Attendance Excusal")
            .errorMessage(
                model.errorMessage
            )
            .interactiveDismissDisabled(model.isSubmitting)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isReasonFocused = false
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if model.isSubmitting {
                    ProgressView("Submitting…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.regularMaterial)
                }
            }
            .onAppear {
                model.prepareForNewSubmission()
            }
        }
    }

    private var canSubmit: Bool {
        reason
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty == false
    }

}
