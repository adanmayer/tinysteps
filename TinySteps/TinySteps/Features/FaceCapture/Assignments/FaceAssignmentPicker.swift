import SwiftUI

struct FaceAssignmentPicker: View {
    let students: [ClassRosterStudent]
    let selectedStudentKey: String?
    let onSelect: (String?) -> Void

    var body: some View {
        NavigationStack {
            List(students) { student in
                Button {
                    onSelect(student.studentKey)
                } label: {
                    HStack {
                        Text(student.displayName)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if student.studentKey == selectedStudentKey {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color(hex: "#8DA67A"))
                        }
                    }
                }
            }
            .navigationTitle("Tap to name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: { onSelect(nil) })
                }
            }
        }
    }
}
