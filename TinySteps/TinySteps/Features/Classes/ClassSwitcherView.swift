import SwiftUI

struct ClassSwitcherView: View {
    let options: [ClassSwitcherOption]
    let onSelect: (ClassContext) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""

    private var filteredOptions: [ClassSwitcherOption] {
        let query = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard query.isEmpty == false else {
            return options
        }

        return options.filter { option in
            let titleMatch = option.title.lowercased().contains(query)
            let subtitleMatch = option.subtitle?.lowercased().contains(query) == true
            return titleMatch || subtitleMatch
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color(hex: "#8DA67A"))
                        TextField("Search classes", text: $searchText)
                            .textInputAutocapitalization(.none)
                            .autocorrectionDisabled()
                            .accessibilityLabel("Search classes")
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(Color(hex: "#FFFDF8"))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color(hex: "#E6D8C2"), lineWidth: 1)
                    )

                    if searchText.isEmpty == false {
                        Button("Clear") {
                            searchText = ""
                        }
                        .buttonStyle(.plain)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(hex: "#8DA67A"))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                List(filteredOptions) { option in
                    Button {
                        onSelect(option.context)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(option.title)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .padding(.vertical, 2)

                                if let subtitle = option.subtitle {
                                    Text(subtitle)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
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
                .scrollContentBackground(.hidden)
                .background(Color(hex: "#FBF6EE"))

                if filteredOptions.isEmpty {
                    Text("No classes found")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.secondary)
                        .padding(.top, 24)
                }
            }
            .navigationTitle("Switch Class")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(hex: "#FBF6EE").ignoresSafeArea())
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
