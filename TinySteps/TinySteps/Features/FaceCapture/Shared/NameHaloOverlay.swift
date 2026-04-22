import SwiftUI

struct NameHaloOverlay: View {
    let faces: [FaceCaptureFace]
    let bounds: CGRect
    let onTapUnknown: (FaceCaptureFace) -> Void

    private let haloSize: CGFloat = 88
    private let textPillHeight: CGFloat = 32

    var body: some View {
        ForEach(faces) { face in
            let mapped = mappedRect(for: face)
            let centerX = clamped(mapped.midX, min: bounds.minX + haloSize / 2, max: bounds.maxX - haloSize / 2)
            let centerY = clamped(mapped.midY, min: bounds.minY + haloSize / 2, max: bounds.maxY - haloSize / 2)
            let labelX = labelPositionX(for: face.label, centerX: centerX)
            let labelY = clamped(centerY + haloSize * 0.58, min: bounds.minY + textPillHeight, max: bounds.maxY - textPillHeight)

            Group {
                Circle()
                    .fill(haloBackground(for: face.label))
                    .overlay(
                        Circle()
                            .strokeBorder(
                                haloColor(for: face.label),
                                style: haloStroke(for: face.label)
                            )
                    )
                    .frame(width: haloSize, height: haloSize)
                    .overlay {
                        ZStack {
                            if case .unknown = face.label {
                                Text("?")
                                    .font(.system(size: 34, weight: .bold))
                            }
                        }
                        .foregroundStyle(faceLabelColor(for: face.label))
                    }
                    .position(x: centerX, y: centerY)

                Text(labelText(for: face.label))
                    .font(.system(size: 18, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(haloFill(for: face.label))
                    .foregroundStyle(faceLabelColor(for: face.label))
                    .clipShape(Capsule())
                    .position(x: labelX, y: labelY)
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

    private func haloBackground(for label: FaceCaptureLabel) -> Color {
        switch label {
        case .matched:
            return Color(hex: "#8DA67A").opacity(0.12)
        case .unknown:
            return Color(hex: "#D99B8F").opacity(0.16)
        }
    }

    private func haloStroke(for label: FaceCaptureLabel) -> StrokeStyle {
        switch label {
        case .matched:
            return StrokeStyle(lineWidth: 5)
        case .unknown:
            return StrokeStyle(lineWidth: 3, dash: [8, 6])
        }
    }

    private func haloFill(for label: FaceCaptureLabel) -> Color {
        switch label {
        case .matched:
            return Color(hex: "#8DA67A").opacity(0.9)
        case .unknown:
            return Color(hex: "#FBF6EE").opacity(0.72)
        }
    }

    private func faceLabelColor(for label: FaceCaptureLabel) -> Color {
        switch label {
        case .matched:
            return .white
        case .unknown:
            return Color(hex: "#3A342E")
        }
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

    private func labelPositionX(for label: FaceCaptureLabel, centerX: CGFloat) -> CGFloat {
        switch label {
        case .matched:
            return centerX
        case .unknown:
            return clamped(centerX + haloSize * 0.62, min: bounds.minX + 76, max: bounds.maxX - 76)
        }
    }

    private func clamped(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minValue), maxValue)
    }
}
