import Foundation
import CoreML

struct MLFaceEmbedder {
    enum Error: LocalizedError {
        case modelUnavailable
        case missingInput
        case missingOutput
        case outputTypeMismatch

        var errorDescription: String? {
            switch self {
            case .modelUnavailable:
                return "AdaFace model resource was not found in the app bundle."
            case .missingInput:
                return "Unable to create model input feature."
            case .missingOutput:
                return "Model output feature is not available."
            case .outputTypeMismatch:
                return "Model output is not a floating array."
            }
        }
    }

    private let model: MLModel

    init() throws {
        let modelURL = try Self.findModelPackage()
        model = try MLModel(contentsOf: modelURL)
    }

    func embed(_ alignedFace: AlignedFace) async throws -> FaceEmbedding {
        let inputName = try Self.inputFeatureName(from: model)
        guard let inputConstraint = model.modelDescription.inputDescriptionsByName[inputName]?.imageConstraint else {
            throw Error.missingInput
        }

        let featureValue = try MLFeatureValue(
            cgImage: alignedFace.image,
            constraint: inputConstraint
        )

        let input = try MLDictionaryFeatureProvider(dictionary: [inputName: featureValue])
        let output = try await MainActor.run {
            try self.model.prediction(from: input)
        }

        let outputFeatureName = Self.outputFeatureName(from: model)
        let outputFeature = outputFeatureName.flatMap({ output.featureValue(for: $0) }) ??
            output.featureValue(for: output.featureNames.first ?? "")

        guard let outputFeature else {
            throw Error.missingOutput
        }

        guard let multiArray = outputFeature.multiArrayValue else {
            throw Error.outputTypeMismatch
        }

        var vector: [Float] = []
        vector.reserveCapacity(multiArray.count)
        var magnitude: Float = 0
        let count = multiArray.count

        switch multiArray.dataType {
        case .double:
            let pointer = multiArray.dataPointer.bindMemory(to: Double.self, capacity: count)
            for index in 0..<count {
                let value = Float(pointer[index])
                vector.append(value)
                magnitude += value * value
            }
        case .float32:
            let pointer = multiArray.dataPointer.bindMemory(to: Float.self, capacity: count)
            for index in 0..<count {
                let value = pointer[index]
                vector.append(value)
                magnitude += value * value
            }
        case .float16:
            let pointer = multiArray.dataPointer.bindMemory(to: Float16.self, capacity: count)
            for index in 0..<count {
                let value = Float(pointer[index])
                vector.append(value)
                magnitude += value * value
            }
        default:
            throw Error.outputTypeMismatch
        }
        let scale = magnitude > 0 ? (1 / sqrtf(magnitude)) : 0
        var normalized = vector
        if scale > 0 {
            for i in 0..<normalized.count {
                normalized[i] *= scale
            }
        }

        var vectorData = Data(capacity: normalized.count * MemoryLayout<Float>.size)
        for value in normalized {
            var byteValue = value
            vectorData.append(Data(bytes: &byteValue, count: MemoryLayout<Float>.size))
        }

        return FaceEmbedding(
            vector: normalized,
            vectorLength: normalized.count,
            elementType: Int(MLMultiArrayDataType.float32.rawValue),
            data: vectorData
        )
    }

    private static func findModelPackage() throws -> URL {
        if let compiledURL = Bundle.main.url(forResource: "FaceEmbedder", withExtension: "mlmodelc") {
            return compiledURL
        }
        if let packageURL = Bundle.main.url(forResource: "FaceEmbedder", withExtension: "mlpackage") {
            return packageURL
        }
        if let altURL = Bundle.main.url(forResource: "FaceEmbedder", withExtension: nil, subdirectory: nil) {
            return altURL
        }
        throw Error.modelUnavailable
    }

    private static func inputFeatureName(from model: MLModel) throws -> String {
        let feature = model.modelDescription.inputDescriptionsByName
        guard let name = feature.keys.first(where: { feature[$0]?.type == .image }) else {
            throw Error.missingInput
        }
        return name
    }

    private static func outputFeatureName(from model: MLModel) -> String? {
        model.modelDescription.outputDescriptionsByName.keys.first
    }
}
