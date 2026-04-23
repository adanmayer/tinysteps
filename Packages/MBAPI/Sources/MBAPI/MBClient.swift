import Foundation

public enum MBAPIRole: String, Codable, Sendable {
    case parent
    case student
    case teacher
    case advisor
}

public extension MBAPIRole {
    var urlPathComponent: String {
        switch self {
        case .advisor:
            return MBAPIRole.teacher.rawValue
        case .parent, .student, .teacher:
            return rawValue
        }
    }
}

public struct MBSessionContext: Equatable, Sendable {
    public let apiBaseURL: URL
    public let accessToken: String
    public let role: MBAPIRole
    public let childID: String?

    public init(apiBaseURL: URL, accessToken: String, role: MBAPIRole = .parent, childID: String? = nil) {
        self.apiBaseURL = apiBaseURL
        self.accessToken = accessToken
        self.role = role
        self.childID = childID
    }
}

protocol MBEndpointRequesting: Sendable {
    func loadItems<Response: Decodable>(
        as responseType: Response.Type,
        from endpointPath: String,
        in context: MBSessionContext,
        query: [String: String]
    ) async throws -> [Response]

    func loadObject<Response: Decodable>(
        as responseType: Response.Type,
        from endpointPath: String,
        in context: MBSessionContext,
        query: [String: String]
    ) async throws -> Response

    func send(
        to endpointPath: String,
        in context: MBSessionContext,
        method: String,
        query: [String: String],
        body: Data?
    ) async throws

    func send<Response: Decodable, Body: Encodable>(
        _ responseType: Response.Type,
        to endpointPath: String,
        in context: MBSessionContext,
        method: String,
        query: [String: String],
        body: Body
    ) async throws -> Response

    func uploadMultipart<Response: Decodable>(
        as responseType: Response.Type,
        to endpointPath: String,
        in context: MBSessionContext,
        query: [String: String],
        file: MBMultipartFile
    ) async throws -> Response
}

struct MBMultipartFile: Sendable {
    let fieldName: String
    let filename: String
    let mimeType: String
    let data: Data
}

extension MBEndpointRequesting {
    func loadItems<Response: Decodable>(
        as responseType: Response.Type,
        from endpointPath: String,
        in context: MBSessionContext
    ) async throws -> [Response] {
        try await loadItems(
            as: responseType,
            from: endpointPath,
            in: context,
            query: [:]
        )
    }

    func loadObject<Response: Decodable>(
        as responseType: Response.Type,
        from endpointPath: String,
        in context: MBSessionContext
    ) async throws -> Response {
        try await loadObject(
            as: responseType,
            from: endpointPath,
            in: context,
            query: [:]
        )
    }
}

public enum MBClientError: LocalizedError, Equatable, Sendable {
    case invalidResponse
    case unexpectedStatusCode(Int)
    case decodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "The ManageBac API returned an invalid response."
        case .unexpectedStatusCode(let statusCode):
            "The ManageBac API returned HTTP \(statusCode)."
        case .decodingFailed(let message):
            "The ManageBac API response could not be decoded: \(message)"
        }
    }
}

public protocol MBClient: Sendable {
    var children: any MBChildrenEndpoint { get }
    var classes: any MBClassesEndpoint { get }
    var classTasks: any MBClassTaskEndpoint { get }
    var classUnits: any MBClassUnitEndpoint { get }
    var general: any MBGeneralEndpoint { get }
    var parentAssociation: any MBParentAssociationEndpoint { get }
    var portfolio: any MBPortfolioEndpoint { get }
    var files: any MBFilesEndpoint { get }
    var members: any MBMembersEndpoint { get }
    var unitComponents: any MBUnitComponentsEndpoint { get }
    var schoolThemes: any MBSchoolThemesEndpoint { get }
}

public extension MBClient {
    public func listChildren(in context: MBSessionContext) async throws -> [MBChild] {
        try await children.list(in: context)
    }

    public func listClasses(in context: MBSessionContext) async throws -> [MBClass] {
        try await classes.list(in: context)
    }

    public func listClasses(
        in context: MBSessionContext,
        query: [String: String]
    ) async throws -> [MBClass] {
        try await classes.list(in: context, query: query)
    }

    public func listClassTasks(
        in context: MBSessionContext,
        classID: String,
        query: [String: String] = [:]
    ) async throws -> [MBClassTask] {
        try await classTasks.list(in: context, classID: classID, query: query)
    }

    public func listClassUnits(
        in context: MBSessionContext,
        classID: String,
        query: [String: String] = [:]
    ) async throws -> [MBClassUnit] {
        try await classUnits.list(in: context, classID: classID, query: query)
    }

    public func listClassMembers(
        in context: MBSessionContext,
        classID: String,
        roleFilter: String? = nil
    ) async throws -> [MBMember] {
        try await members.list(in: context, classID: classID, roleFilter: roleFilter)
    }

    public func listClassFiles(
        in context: MBSessionContext,
        classID: String,
        folderID: String? = nil
    ) async throws -> [MBFile] {
        try await files.list(in: context, classID: classID, folderID: folderID)
    }

    public func listParentAssociationFiles(
        in context: MBSessionContext,
        folderID: String? = nil
    ) async throws -> [MBFile] {
        try await files.listParentAssociation(in: context, folderID: folderID)
    }

    public func listParentAssociationMenu(
        in context: MBSessionContext
    ) async throws -> [MBParentAssociationMenuItem] {
        try await parentAssociation.listMenu(in: context)
    }

    public func loadSchool(
        in context: MBSessionContext
    ) async throws -> MBSchool {
        try await general.school(in: context)
    }

    public func loadAccount(
        in context: MBSessionContext
    ) async throws -> MBAccount {
        try await general.account(in: context)
    }

    public func listAttendanceExcusals(
        in context: MBSessionContext
    ) async throws -> [MBAttendanceExcusal] {
        try await parentAssociation.listAttendanceExcusals(in: context)
    }

    public func submitAttendanceExcusal(
        in context: MBSessionContext,
        submission: MBAttendanceExcusalSubmission
    ) async throws {
        try await parentAssociation.submitAttendanceExcusal(in: context, submission: submission)
    }

    public func listPortfolioTimeline(
        in context: MBSessionContext,
        classID: String? = nil,
        query: [String: String] = [:]
    ) async throws -> [Portfolio.TimelineItem] {
        try await portfolio.listTimeline(in: context, classID: classID, query: query)
    }

    public func createPortfolioClassResource<Payload: Encodable>(
        in context: MBSessionContext,
        classID: String,
        kind: Portfolio.ResourceKind,
        payload: Payload
    ) async throws -> Portfolio.ResourceCreateResponse {
        try await portfolio.createClassResource(
            in: context,
            classID: classID,
            kind: kind,
            payload: payload
        )
    }

    public func createPortfolioClassNote<Payload: Encodable>(
        in context: MBSessionContext,
        classID: String,
        payload: Payload
    ) async throws -> Portfolio.ResourceCreateResponse {
        try await createPortfolioClassResource(
            in: context,
            classID: classID,
            kind: .notes,
            payload: payload
        )
    }

    public func createPortfolioClassPhoto<Payload: Encodable>(
        in context: MBSessionContext,
        classID: String,
        payload: Payload
    ) async throws -> Portfolio.ResourceCreateResponse {
        try await createPortfolioClassResource(
            in: context,
            classID: classID,
            kind: .photos,
            payload: payload
        )
    }

    public func uploadPortfolioPhoto(
        in context: MBSessionContext,
        imageData: Data,
        filename: String = "portfolio-photo.jpg",
        mimeType: String = "image/jpeg"
    ) async throws -> Portfolio.UploadedPhoto {
        try await portfolio.uploadPhoto(
            in: context,
            imageData: imageData,
            filename: filename,
            mimeType: mimeType
        )
    }

    public func loadClassPortfolioSettings(
        in context: MBSessionContext,
        programID: String
    ) async throws -> Portfolio.Settings {
        try await portfolio.loadClassPortfolioSettings(
            in: context,
            programID: programID
        )
    }

    public func loadStandardsComponents(
        in context: MBSessionContext,
        forUnitID unitID: String,
        query: [String: String] = [:]
    ) async throws -> MBUnitComponents {
        try await unitComponents.loadComponents(in: context, unitID: unitID, query: query)
    }

    public func loadStandardsComponents(
        in context: MBSessionContext,
        classID: String,
        forUnitID unitID: String,
        query: [String: String] = [:]
    ) async throws -> MBUnitComponents {
        try await unitComponents.loadComponents(in: context, classID: classID, unitID: unitID, query: query)
    }

    public func loadSchoolThemes(
        in context: MBSessionContext,
        query: [String: String] = [:]
    ) async throws -> [MBTRTheme] {
        try await schoolThemes.loadThemes(in: context, query: query)
    }
}

public struct MBLiveClient: MBClient {
    private let requestor: MBAPIRequestor

    public let children: any MBChildrenEndpoint
    public let classes: any MBClassesEndpoint
    public let classTasks: any MBClassTaskEndpoint
    public let classUnits: any MBClassUnitEndpoint
    public let general: any MBGeneralEndpoint
    public let parentAssociation: any MBParentAssociationEndpoint
    public let portfolio: any MBPortfolioEndpoint
    public let files: any MBFilesEndpoint
    public let members: any MBMembersEndpoint
    public let unitComponents: any MBUnitComponentsEndpoint
    public let schoolThemes: any MBSchoolThemesEndpoint

    public init(
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder(),
        demoDataStore: MBAPIDemoDataStore? = nil
    ) {
        let requestor = MBAPIRequestor(
            session: session,
            decoder: decoder,
            demoDataStore: demoDataStore
        )
        self.requestor = requestor
        self.children = MBChildrenEndpointClient(requester: requestor)
        self.classes = MBClassesEndpointClient(requester: requestor)
        self.classTasks = MBClassTaskEndpointClient(requester: requestor)
        self.classUnits = MBClassUnitEndpointClient(requester: requestor)
        self.general = MBGeneralEndpointClient(requester: requestor)
        self.parentAssociation = MBParentAssociationEndpointClient(requester: requestor)
        self.portfolio = MBPortfolioEndpointClient(requester: requestor)
        self.files = MBFilesEndpointClient(requester: requestor)
        self.members = MBMembersEndpointClient(requester: requestor)
        self.unitComponents = MBUnitComponentsEndpointClient(requester: requestor)
        self.schoolThemes = MBSchoolThemesEndpointClient(requester: requestor)
    }
}

public struct MBMockClient: MBClient {
    private let requestor: MBAPIMockRequestor

    public let children: any MBChildrenEndpoint
    public let classes: any MBClassesEndpoint
    public let classTasks: any MBClassTaskEndpoint
    public let classUnits: any MBClassUnitEndpoint
    public let general: any MBGeneralEndpoint
    public let parentAssociation: any MBParentAssociationEndpoint
    public let portfolio: any MBPortfolioEndpoint
    public let files: any MBFilesEndpoint
    public let members: any MBMembersEndpoint
    public let unitComponents: any MBUnitComponentsEndpoint
    public let schoolThemes: any MBSchoolThemesEndpoint

    public init(
        demoDataStore: MBAPIDemoDataStore,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        let requestor = MBAPIMockRequestor(
            demoDataStore: demoDataStore,
            decoder: decoder
        )
        self.requestor = requestor
        self.children = MBChildrenEndpointClient(requester: requestor)
        self.classes = MBClassesEndpointClient(requester: requestor)
        self.classTasks = MBClassTaskEndpointClient(requester: requestor)
        self.classUnits = MBClassUnitEndpointClient(requester: requestor)
        self.general = MBGeneralEndpointClient(requester: requestor)
        self.parentAssociation = MBParentAssociationEndpointClient(requester: requestor)
        self.portfolio = MBPortfolioEndpointClient(requester: requestor)
        self.files = MBFilesEndpointClient(requester: requestor)
        self.members = MBMembersEndpointClient(requester: requestor)
        self.unitComponents = MBUnitComponentsEndpointClient(requester: requestor)
        self.schoolThemes = MBSchoolThemesEndpointClient(requester: requestor)
    }
}
