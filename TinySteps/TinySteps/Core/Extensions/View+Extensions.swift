import SwiftUI

struct ErrorMessageModifier: ViewModifier {
    let message: String?
    let font: Font
    let color: Color
    let multiline: Bool
    let horizontalPadding: CGFloat
    let topPadding: CGFloat

    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content
            if let message {
                Text(message)
                    .font(font)
                    .foregroundStyle(color)
                    .fixedSize(horizontal: false, vertical: multiline)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, topPadding)
            }
        }
    }
}

extension View {
    func errorMessage(
        _ message: String?,
        font: Font = .footnote,
        color: Color = .red,
        multiline: Bool = true,
        horizontalPadding: CGFloat = 16,
        topPadding: CGFloat = 10
    ) -> some View {
        modifier(
            ErrorMessageModifier(
                message: message,
                font: font,
                color: color,
                multiline: multiline,
                horizontalPadding: horizontalPadding,
                topPadding: topPadding
            )
        )
    }
}
