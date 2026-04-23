import SwiftUI

struct ClassPageTitleHeader: View {
    let title: String
    let classTitle: String
    let canShowClassSwitcher: Bool
    let onShowClassSwitcher: () -> Void
    let secondarySystemImage: String?
    let secondaryAccessibilityLabel: String
    let onSecondaryAction: (() -> Void)?

    init(
        title: String,
        classTitle: String,
        canShowClassSwitcher: Bool,
        onShowClassSwitcher: @escaping () -> Void,
        secondarySystemImage: String? = nil,
        secondaryAccessibilityLabel: String = "",
        onSecondaryAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.classTitle = classTitle
        self.canShowClassSwitcher = canShowClassSwitcher
        self.onShowClassSwitcher = onShowClassSwitcher
        self.secondarySystemImage = secondarySystemImage
        self.secondaryAccessibilityLabel = secondaryAccessibilityLabel
        self.onSecondaryAction = onSecondaryAction
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color(hex: "#3A342E"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(classTitle.isEmpty ? "Choose a class" : classTitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(hex: "#6E6456"))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 12)

            HStack(spacing: 10) {
                headerButton(
                    systemImage: "chevron.down",
                    accessibilityLabel: "Switch class",
                    isEnabled: canShowClassSwitcher,
                    action: onShowClassSwitcher
                )

                if let secondarySystemImage, let onSecondaryAction {
                    headerButton(
                        systemImage: secondarySystemImage,
                        accessibilityLabel: secondaryAccessibilityLabel,
                        isEnabled: true,
                        action: onSecondaryAction
                    )
                }
            }
        }
    }

    private func headerButton(
        systemImage: String,
        accessibilityLabel: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color(hex: "#3A342E"))
                .frame(width: 44, height: 44)
                .background(Color(hex: "#FFFDF8"))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
                .overlay(
                    Circle()
                        .stroke(Color(hex: "#E6D8C2"), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityLabel(accessibilityLabel)
    }
}
