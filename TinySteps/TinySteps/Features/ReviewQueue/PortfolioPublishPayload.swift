import Foundation

struct PortfolioOutcomePayload: Equatable, Sendable, Encodable {
    var atlIDs: [Int] = []
    var learnerProfileIDs: [Int] = []
    var unitsStandardIDs: [Int] = []
    var standardIDs: [Int] = []
    var unitsSyllabusIDs: [Int]?
    var syllabusIDs: [Int]?
    var unitsExpectationIDs: [Int] = []
    var expectationIDs: [Int] = []
    var transdisciplinaryThemesIDs: [Int]?
    var transdisciplinaryThemeDescriptionsIDs: [Int]?

    static func empty(isPYP: Bool) -> PortfolioOutcomePayload {
        PortfolioOutcomePayload(
            unitsSyllabusIDs: isPYP ? nil : [],
            syllabusIDs: isPYP ? nil : [],
            transdisciplinaryThemesIDs: isPYP ? [] : nil,
            transdisciplinaryThemeDescriptionsIDs: isPYP ? [] : nil
        )
    }

    private enum CodingKeys: String, CodingKey {
        case atlIDs = "atl_ids"
        case learnerProfileIDs = "learner_profile_ids"
        case unitsStandardIDs = "units_standard_ids"
        case standardIDs = "standard_ids"
        case unitsSyllabusIDs = "units_syllabus_ids"
        case syllabusIDs = "syllabus_ids"
        case unitsExpectationIDs = "units_expectation_ids"
        case expectationIDs = "expectation_ids"
        case transdisciplinaryThemesIDs = "transdisciplinary_themes_ids"
        case transdisciplinaryThemeDescriptionsIDs = "transdisciplinary_theme_descriptions_ids"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(atlIDs, forKey: .atlIDs)
        try container.encode(learnerProfileIDs, forKey: .learnerProfileIDs)
        try container.encode(unitsStandardIDs, forKey: .unitsStandardIDs)
        try container.encode(standardIDs, forKey: .standardIDs)
        if let unitsSyllabusIDs {
            try container.encode(unitsSyllabusIDs, forKey: .unitsSyllabusIDs)
        } else {
            try container.encodeNil(forKey: .unitsSyllabusIDs)
        }
        if let syllabusIDs {
            try container.encode(syllabusIDs, forKey: .syllabusIDs)
        } else {
            try container.encodeNil(forKey: .syllabusIDs)
        }
        try container.encode(unitsExpectationIDs, forKey: .unitsExpectationIDs)
        try container.encode(expectationIDs, forKey: .expectationIDs)
        if let transdisciplinaryThemesIDs {
            try container.encode(transdisciplinaryThemesIDs, forKey: .transdisciplinaryThemesIDs)
        } else {
            try container.encodeNil(forKey: .transdisciplinaryThemesIDs)
        }
        if let transdisciplinaryThemeDescriptionsIDs {
            try container.encode(transdisciplinaryThemeDescriptionsIDs, forKey: .transdisciplinaryThemeDescriptionsIDs)
        } else {
            try container.encodeNil(forKey: .transdisciplinaryThemeDescriptionsIDs)
        }
    }
}

struct PortfolioNoteCreatePayload: Encodable, Sendable {
    let title: String
    let body: String
    let startDate: String
    let presetID: String
    let allowedUserRoles: [String]
    let notifyViaEmail: Bool
    let assignedUserIDs: [Int]
    let shareToStudentPortfolios: Bool
    let outcome: PortfolioOutcomePayload

    private enum CodingKeys: String, CodingKey {
        case title
        case body
        case startDate = "start_date"
        case presetID = "preset_id"
        case allowedUserRoles = "allowed_user_roles"
        case notifyViaEmail = "notify_via_email"
        case assignedUserIDs = "assigned_user_ids"
        case shareToStudentPortfolios = "share_to_student_portfolios"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(body, forKey: .body)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(presetID, forKey: .presetID)
        try container.encode(allowedUserRoles, forKey: .allowedUserRoles)
        try container.encode(notifyViaEmail, forKey: .notifyViaEmail)
        try container.encode(assignedUserIDs, forKey: .assignedUserIDs)
        try container.encode(shareToStudentPortfolios, forKey: .shareToStudentPortfolios)
        try outcome.encode(to: encoder)
    }
}

struct PortfolioPhotoCreatePayload: Encodable, Sendable {
    let title: String
    let description: String
    let startDate: String
    let photoIDs: [Int]
    let allowedUserRoles: [String]
    let notifyViaEmail: Bool
    let assignedUserIDs: [Int]
    let shareToStudentPortfolios: Bool
    let outcome: PortfolioOutcomePayload

    private enum CodingKeys: String, CodingKey {
        case title
        case description
        case startDate = "start_date"
        case photoIDs = "photo_ids"
        case allowedUserRoles = "allowed_user_roles"
        case notifyViaEmail = "notify_via_email"
        case assignedUserIDs = "assigned_user_ids"
        case shareToStudentPortfolios = "share_to_student_portfolios"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(photoIDs, forKey: .photoIDs)
        try container.encode(allowedUserRoles, forKey: .allowedUserRoles)
        try container.encode(notifyViaEmail, forKey: .notifyViaEmail)
        try container.encode(assignedUserIDs, forKey: .assignedUserIDs)
        try container.encode(shareToStudentPortfolios, forKey: .shareToStudentPortfolios)
        try outcome.encode(to: encoder)
    }
}

enum PortfolioPublishPayloadFactory {
    static func notePayload(
        for draft: ObservationCaptureDraft,
        presetID: String,
        assignedUserIDs: [Int],
        outcome: PortfolioOutcomePayload
    ) throws -> PortfolioNoteCreatePayload {
        let body = draft.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard body.isEmpty == false else {
            throw ObservationDraftPublishError.validation("Observation text is empty. This draft stays on this device.")
        }

        return PortfolioNoteCreatePayload(
            title: "Observation",
            body: body,
            startDate: localDateString(from: draft.createdAt),
            presetID: presetID,
            allowedUserRoles: defaultAllowedUserRoles,
            notifyViaEmail: false,
            assignedUserIDs: assignedUserIDs,
            shareToStudentPortfolios: false,
            outcome: outcome
        )
    }

    static func photoPayload(
        for draft: FaceCaptureDraft,
        photoID: Int,
        assignedUserIDs: [Int]
    ) -> PortfolioPhotoCreatePayload {
        PortfolioPhotoCreatePayload(
            title: "Observation photo",
            description: "",
            startDate: localDateString(from: draft.capturedAt),
            photoIDs: [photoID],
            allowedUserRoles: defaultAllowedUserRoles,
            notifyViaEmail: false,
            assignedUserIDs: assignedUserIDs,
            shareToStudentPortfolios: false,
            outcome: .empty(isPYP: false)
        )
    }

    private static var defaultAllowedUserRoles: [String] {
        ["student", "parent", "teacher"]
    }

    private static func localDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
