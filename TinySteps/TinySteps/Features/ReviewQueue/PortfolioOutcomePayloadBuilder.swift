import Foundation

struct PortfolioOutcomePayloadBuilder: Sendable {
    func build(
        from suggestions: [ObservationStandardTagSuggestion],
        isPYP: Bool
    ) throws -> PortfolioOutcomePayload {
        var payload = PortfolioOutcomePayload.empty(isPYP: isPYP)
        var unitsStandardIDs: [Int] = []
        var standardIDs: [Int] = []
        var unitsSyllabusIDs: [Int] = []
        var syllabusIDs: [Int] = []
        var unitsExpectationIDs: [Int] = []
        var expectationIDs: [Int] = []
        var themeIDs: [Int] = []
        var themeDescriptionIDs: [Int] = []

        for suggestion in suggestions {
            switch suggestion.sourceIdentity {
            case .standard(let unitID, let standardID):
                unitsStandardIDs.append(try numericID(unitID, label: "unit"))
                standardIDs.append(try numericID(standardID, label: "standard"))
            case .syllabus(let unitID, let syllabusID):
                unitsSyllabusIDs.append(try numericID(unitID, label: "unit"))
                syllabusIDs.append(try numericID(syllabusID, label: "syllabus"))
            case .scopeSequence(let unitID, let expectationID):
                unitsExpectationIDs.append(try numericID(unitID, label: "unit"))
                expectationIDs.append(try numericID(expectationID, label: "expectation"))
            case .pypTheme(let themeID):
                themeIDs.append(try numericID(themeID, label: "PYP theme"))
            case .pypThemeDescription(let themeID, let descriptionID):
                themeIDs.append(try numericID(themeID, label: "PYP theme"))
                themeDescriptionIDs.append(try numericID(descriptionID, label: "PYP theme description"))
            case .unresolved:
                throw ObservationDraftPublishError.validation("One selected standard cannot be published because it has no server id. Remove it and try again.")
            }
        }

        payload.unitsStandardIDs = stableUnique(unitsStandardIDs)
        payload.standardIDs = stableUnique(standardIDs)
        if isPYP == false {
            payload.unitsSyllabusIDs = stableUnique(unitsSyllabusIDs)
            payload.syllabusIDs = stableUnique(syllabusIDs)
        }
        payload.unitsExpectationIDs = stableUnique(unitsExpectationIDs)
        payload.expectationIDs = stableUnique(expectationIDs)
        if isPYP {
            payload.transdisciplinaryThemesIDs = stableUnique(themeIDs)
            payload.transdisciplinaryThemeDescriptionsIDs = stableUnique(themeDescriptionIDs)
        }

        return payload
    }

    private func numericID(_ rawValue: String, label: String) throws -> Int {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed) else {
            throw ObservationDraftPublishError.validation("Selected \(label) tag has a non-numeric server id. Remove it and try again.")
        }
        return value
    }

    private func stableUnique(_ values: [Int]) -> [Int] {
        var seen: Set<Int> = []
        var result: [Int] = []
        for value in values where seen.insert(value).inserted {
            result.append(value)
        }
        return result
    }
}
