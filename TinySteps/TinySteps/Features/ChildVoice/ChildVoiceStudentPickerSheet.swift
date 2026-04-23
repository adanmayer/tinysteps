import SwiftUI

struct ChildVoiceStudentPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let children: [ChildVoiceChild]
    let onSelect: (ChildVoiceChild) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if sortedChildren.isEmpty {
                    ContentUnavailableView(
                        "No children available",
                        systemImage: "person.crop.circle.badge.questionmark",
                        description: Text("This class did not provide selectable students for child voice.")
                    )
                } else {
                    List(sortedChildren) { child in
                        Button {
                            onSelect(child)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Text(normalizedDisplayName(for: child).prefix(2).uppercased())
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Color(hex: "#8DA67A"))
                                    .clipShape(Circle())

                                Text(normalizedDisplayName(for: child))
                                    .font(.body)
                                    .foregroundStyle(Color(hex: "#3A342E"))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
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

    private var sortedChildren: [ChildVoiceChild] {
        children.sorted {
            normalizedDisplayName(for: $0)
                .localizedCaseInsensitiveCompare(normalizedDisplayName(for: $1)) == .orderedAscending
        }
    }

    private func normalizedDisplayName(for child: ChildVoiceChild) -> String {
        let displayName = child.displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if displayName.isEmpty {
            return "Child"
        }

        return displayName
    }
}
