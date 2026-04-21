import SwiftUI

struct ChildSwitcherView: View {
    let options: [ChildSwitcherOption]
    let onSelect: (ChildContext) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(options) { option in
                Button {
                    onSelect(option.context)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.title)
                                .foregroundStyle(.primary)

                            if let subtitle = option.subtitle {
                                Text(subtitle)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if option.isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Switch Child")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}