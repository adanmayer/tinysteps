import SwiftUI

struct NameHaloOverlay: View {
    let faces: [FaceCaptureFace]
    let bounds: CGRect
    let onTapUnknown: (FaceCaptureFace) -> Void

    private let haloSize: CGFloat = 38
    private let textPillHeight: CGFloat = 24

    var body: some View {
        ForEach(faces) { face in
            let mapped = mappedRect(for: face)
            Group {
                Circle()
                    .strokeBorder(haloColor(for: face.label), lineWidth: 4)
                    .frame(width: haloSize, height: haloSize)
                    .overlay {
                        ZStack {
                            if case .unknown = face.label {
                                Text("?")
                                    .font(.headline.weight(.bold))
                            }
                        }
                        .foregroundStyle(faceLabelColor(for: face.label))
                    }
                    .position(
                        x: mapped.midX,
                        y: mapped.minY - haloSize * 0.35
                    )

                Text(labelText(for: face.label))
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(haloFill(for: face.label))
                    .foregroundStyle(faceLabelColor(for: face.label))
                    .clipShape(Capsule())
                    .position(
                        x: mapped.midX,
                        y: mapped.minY - haloSize * 0.35 - textPillHeight
                    )
            }
            .onTapGesture {
                if case .unknown = face.label {
                    onTapUnknown(face)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText(for: face.label))
        }
    }

    private func mappedRect(for face: FaceCaptureFace) -> CGRect {
        CGRect(
            x: bounds.minX + (face.bounds.origin.x * bounds.width),
            y: bounds.minY + ((1 - face.bounds.maxY) * bounds.height),
            width: face.bounds.width * bounds.width,
            height: face.bounds.height * bounds.height
        )
    }

    private func haloColor(for label: FaceCaptureLabel) -> Color {
        switch label {
        case .matched:
            return Color(hex: "#8DA67A")
        case .unknown:
            return Color(hex: "#D99B8F")
        }
    }

    private func haloFill(for label: FaceCaptureLabel) -> Color {
        switch label {
        case .matched:
            return Color(hex: "#8DA67A").opacity(0.82)
        case .unknown:
            return Color(hex: "#D99B8F").opacity(0.22)
        }
    }

    private func faceLabelColor(for label: FaceCaptureLabel) -> Color {
        .white
    }

    private func labelText(for label: FaceCaptureLabel) -> String {
        switch label {
        case .matched(_, let displayName, _):
            return firstName(from: displayName)
        case .unknown:
            return "Tap to name"
        }
    }

    private func firstName(from fullName: String) -> String {
        fullName
            .split(separator: " ")
            .first
            .map(String.init) ?? fullName
    }

    private func accessibilityText(for label: FaceCaptureLabel) -> String {
        switch label {
        case .matched(let studentKey, let displayName, _):
            return "\(displayName), matched. (\(studentKey))"
        case .unknown:
            return "Unknown face. Tap to name."
        }
    }
}
