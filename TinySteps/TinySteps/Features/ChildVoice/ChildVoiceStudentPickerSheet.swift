import SwiftUI

struct ChildVoiceStudentPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let children: [ChildVoiceChild]
    let onSelect: (ChildVoiceChild) -> Void

    var body: some View {
        NavigationStack {
            List(children.sorted(by: { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending })) { child in
                Button {
                    onSelect(child)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Text(child.displayName.prefix(2).uppercased())
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Color(hex: "#8DA67A"))
                            .clipShape(Circle())

                        Text(child.displayName)
                            .font(.body)
                            .foregroundStyle(Color(hex: "#3A342E"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Select child")
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
