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

        let outputFeature = Self.outputFeatureValue(
            from: model,
            output: output
        )

        guard let outputFeature else {
            throw Error.missingOutput
        }

        let vectorValues = Self.extractFloatValues(from: outputFeature)
        guard vectorValues.isEmpty == false else {
            throw Error.outputTypeMismatch
        }

        let count = vectorValues.count
        var vector = vectorValues
        var magnitude: Float = 0
        for index in 0..<count {
            let value = vector[index]
            magnitude += value * value
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
        if let output = model.modelDescription.outputDescriptionsByName["output"] {
            return "output"
        }
        if model.modelDescription.outputDescriptionsByName["output1"] != nil {
            return "output1"
        }
        if let multiArrayOutput = model.modelDescription.outputDescriptionsByName.first(where: {
            $0.value.multiArrayConstraint != nil
        }) {
            return multiArrayOutput.key
        }
        return model.modelDescription.outputDescriptionsByName.keys.first
    }

    private static func outputFeatureValue(
        from model: MLModel,
        output: MLFeatureProvider
    ) -> MLFeatureValue? {
        if let outputName = outputFeatureName(from: model),
           let feature = output.featureValue(for: outputName),
           feature.multiArrayValue != nil {
            return feature
        }

        for name in output.featureNames {
            if let feature = output.featureValue(for: name), feature.multiArrayValue != nil {
                return feature
            }
        }

        return nil
    }

    private static func extractFloatValues(from outputFeature: MLFeatureValue) -> [Float] {
        guard let multiArray = outputFeature.multiArrayValue else {
            return []
        }

        var values = [Float]()
        values.reserveCapacity(multiArray.count)
        for index in 0..<multiArray.count {
            values.append(multiArray[index].floatValue)
        }
        return values
    }
}
