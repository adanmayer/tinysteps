import Foundation

// MARK: - Timeline item

public extension Portfolio {
    public struct TimelineItem: Identifiable, Decodable, Equatable, Sendable {
        public let id: String
        public let logableType: String?
        public let status: String?
        public let createdAt: String?
        public let logable: Logable
        public let labels: [String]
        public let attributedStudents: [AttributedStudent]

        public init(
            id: String,
            logableType: String? = nil,
            status: String? = nil,
            createdAt: String? = nil,
            logable: Logable,
            labels: [String] = [],
            attributedStudents: [AttributedStudent] = []
        ) {
            self.id = id
            self.logableType = logableType
            self.status = status
            self.createdAt = createdAt
            self.logable = logable
            self.labels = labels
            self.attributedStudents = attributedStudents
        }

        public var explicitAttributedStudents: [AttributedStudent] {
            if attributedStudents.isEmpty == false {
                return attributedStudents
            }

            return logable.attributedStudents
        }

        public var title: String {
            logable.title ?? "Portfolio item"
        }

        public var summary: String? {
            logable.summaryText
        }

        public var createdDate: Date? {
            guard let createdAt else {
                return nil
            }

            let withFractions = ISO8601DateFormatter()
            withFractions.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let parsed = withFractions.date(from: createdAt) {
                return parsed
            }

            let withoutFractions = ISO8601DateFormatter()
            withoutFractions.formatOptions = [.withInternetDateTime]
            return withoutFractions.date(from: createdAt)
        }

        public var formattedCreatedDate: String? {
            guard let createdDate else {
                return createdAt
            }

            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: createdDate)
        }

        private enum CodingKeys: String, CodingKey {
            case id
            case logableType = "logable_type"
            case status
            case createdAt = "created_at"
            case logable
            case labels
            case students
            case children
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            id = try MBModelCoding.decodeStringID(from: container, forKey: .id)
            logableType = try container.decodeIfPresent(String.self, forKey: .logableType)
            status = try container.decodeIfPresent(String.self, forKey: .status)
            createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
            logable = try container.decodeIfPresent(Logable.self, forKey: .logable) ?? .empty
            labels = TimelineItem.decodeLabelValues(from: container, forKey: .labels)
            attributedStudents = TimelineItem.decodeAttributedStudents(
                from: container,
                forKeys: [.students, .children]
            )
        }

        public struct Logable: Decodable, Equatable, Sendable {
            public let id: String
            public let gid: String?
            public let title: String?
            public let kind: String?
            public let description: String?
            public let body: String?
            public let startDate: String?
            public let presetID: String?
            public let preset: Preset?
            public let event: Event?
            public let labels: [String]
            public let createdBy: Author?
            public let photos: [Photo]
            public let assets: [MBFileAsset]
            public let urls: [String]
            public let starred: Bool?
            public let liked: Bool?
            public let canEdit: Bool?
            public let canComment: Bool?
            public let canConnect: Bool?
            public let canStar: Bool?
            public let canLike: Bool?
            public let canExport: Bool?
            public let attributedStudents: [AttributedStudent]

            public var note: NoteItem? {
                guard isNote else {
                    return nil
                }

                return NoteItem(
                    id: id,
                    gid: gid,
                    title: title,
                    body: body,
                    startDate: startDate,
                    presetID: presetID,
                    preset: preset
                )
            }

            public var photo: PhotoItem {
                PhotoItem(
                    id: id,
                    title: title,
                    description: description,
                    startDate: startDate,
                    photos: photos
                )
            }

            public var file: FileItem {
                FileItem(
                    id: id,
                    title: title,
                    description: description,
                    startDate: startDate,
                    assets: assets
                )
            }

            public var website: WebsiteItem {
                WebsiteItem(
                    id: id,
                    title: title,
                    description: description,
                    startDate: startDate,
                    urls: urls
                )
            }

            public var reflection: ReflectionItem {
                ReflectionItem(
                    id: id,
                    title: title,
                    description: description,
                    startDate: startDate
                )
            }

            public var eventItem: EventItem? {
                guard let event else {
                    return nil
                }

                return EventItem(
                    id: id,
                    title: title,
                    description: description,
                    startDate: startDate,
                    event: event,
                    urls: urls
                )
            }

            public var summaryText: String? {
                let text: String?
                if kind?.lowercased() == "note" {
                    text = body
                } else {
                    text = description
                }

                let trimmed = text?
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                return trimmed?.isEmpty == true ? nil : trimmed
            }

            public var resourceKind: String {
                kind ?? ""
            }

            public var isNote: Bool {
                resourceKind.lowercased() == "note"
            }

            public init(
                id: String,
                gid: String? = nil,
                title: String? = nil,
                kind: String? = nil,
                description: String? = nil,
                body: String? = nil,
                startDate: String? = nil,
                presetID: String? = nil,
                preset: Preset? = nil,
                event: Event? = nil,
                labels: [String] = [],
                createdBy: Author? = nil,
                photos: [Photo] = [],
                assets: [MBFileAsset] = [],
                urls: [String] = [],
                starred: Bool? = nil,
                liked: Bool? = nil,
                canEdit: Bool? = nil,
                canComment: Bool? = nil,
                canConnect: Bool? = nil,
                canStar: Bool? = nil,
                canLike: Bool? = nil,
                canExport: Bool? = nil,
                attributedStudents: [AttributedStudent] = []
            ) {
                self.id = id
                self.gid = gid
                self.title = title
                self.kind = kind
                self.description = description
                self.body = body
                self.startDate = startDate
                self.presetID = presetID
                self.preset = preset
                self.event = event
                self.labels = labels
                self.createdBy = createdBy
                self.photos = photos
                self.assets = assets
                self.urls = urls
                self.starred = starred
                self.liked = liked
                self.canEdit = canEdit
                self.canComment = canComment
                self.canConnect = canConnect
                self.canStar = canStar
                self.canLike = canLike
                self.canExport = canExport
                self.attributedStudents = attributedStudents
            }

            private enum CodingKeys: String, CodingKey {
                case id
                case gid
                case title
                case kind
                case description
                case body
                case presetID = "preset_id"
                case preset
                case startDate = "start_date"
                case event
                case labels
                case createdBy = "created_by"
                case photos
                case assets
                case urls
                case starred
                case liked
                case canEdit = "can_edit"
                case canLike = "can_like"
                case canComment = "can_comment"
                case canStar = "can_star"
                case canExport = "can_export"
                case canConnect = "can_connect"
                case students
                case children
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)

                id = try MBModelCoding.decodeStringID(from: container, forKey: .id)
                gid = try container.decodeIfPresent(String.self, forKey: .gid)
                title = try container.decodeIfPresent(String.self, forKey: .title)
                kind = try container.decodeIfPresent(String.self, forKey: .kind)
                description = try container.decodeIfPresent(String.self, forKey: .description)
                body = try container.decodeIfPresent(String.self, forKey: .body)
                presetID = try container.decodeIfPresent(String.self, forKey: .presetID)
                preset = try? container.decodeIfPresent(Preset.self, forKey: .preset)
                startDate = try container.decodeIfPresent(String.self, forKey: .startDate)
                event = try container.decodeIfPresent(Event.self, forKey: .event)
                labels = TimelineItem.decodeLabelValues(from: container, forKey: .labels)
                createdBy = try container.decodeIfPresent(Author.self, forKey: .createdBy)

                photos = (try? container.decode([Photo].self, forKey: .photos)) ?? []
                assets = (try? container.decode([MBFileAsset].self, forKey: .assets)) ?? []
                urls = (try? container.decode([String].self, forKey: .urls)) ?? []

                starred = try container.decodeIfPresent(Bool.self, forKey: .starred)
                liked = try container.decodeIfPresent(Bool.self, forKey: .liked)
                canEdit = try container.decodeIfPresent(Bool.self, forKey: .canEdit)
                canLike = try container.decodeIfPresent(Bool.self, forKey: .canLike)
                canComment = try container.decodeIfPresent(Bool.self, forKey: .canComment)
                canStar = try container.decodeIfPresent(Bool.self, forKey: .canStar)
                canExport = try container.decodeIfPresent(Bool.self, forKey: .canExport)
                canConnect = try container.decodeIfPresent(Bool.self, forKey: .canConnect)
                attributedStudents = TimelineItem.decodeAttributedStudents(
                    from: container,
                    forKeys: [.students, .children]
                )
            }

            public static let empty = Logable(id: "0")
        }

        public struct NoteItem: Decodable, Equatable, Sendable {
            public let id: String
            public let gid: String?
            public let title: String?
            public let body: String?
            public let description: String?
            public let startDate: String?
            public let presetID: String?
            public let preset: Preset?
            public let starred: Bool?
            public let liked: Bool?
            public let canLike: Bool?
            public let canEdit: Bool?
            public let canComment: Bool?
            public let canStar: Bool?
            public let canExport: Bool?
            public let photos: [Photo]?
            public let assets: [MBFileAsset]?
            public let urls: [String]?

            public var displayText: String {
                body ?? description ?? ""
            }

            public init(
                id: String,
                gid: String? = nil,
                title: String? = nil,
                body: String? = nil,
                description: String? = nil,
                startDate: String? = nil,
                presetID: String? = nil,
                preset: Preset? = nil,
                starred: Bool? = nil,
                liked: Bool? = nil,
                canLike: Bool? = nil,
                canEdit: Bool? = nil,
                canComment: Bool? = nil,
                canStar: Bool? = nil,
                canExport: Bool? = nil,
                photos: [Photo]? = nil,
                assets: [MBFileAsset]? = nil,
                urls: [String]? = nil
            ) {
                self.id = id
                self.gid = gid
                self.title = title
                self.body = body
                self.description = description
                self.startDate = startDate
                self.presetID = presetID
                self.preset = preset
                self.starred = starred
                self.liked = liked
                self.canLike = canLike
                self.canEdit = canEdit
                self.canComment = canComment
                self.canStar = canStar
                self.canExport = canExport
                self.photos = photos
                self.assets = assets
                self.urls = urls
            }
        }

        public struct PhotoItem: Decodable, Equatable, Sendable {
            public let id: String
            public let title: String?
            public let description: String?
            public let startDate: String?
            public let photos: [Photo]
            public let photoIds: [String]?
            public let starred: Bool?
            public let liked: Bool?
            public let canLike: Bool?
            public let canEdit: Bool?
            public let canComment: Bool?
            public let canStar: Bool?
            public let canExport: Bool?

            public init(
                id: String,
                title: String? = nil,
                description: String? = nil,
                startDate: String? = nil,
                photos: [Photo] = [],
                photoIds: [String]? = nil,
                starred: Bool? = nil,
                liked: Bool? = nil,
                canLike: Bool? = nil,
                canEdit: Bool? = nil,
                canComment: Bool? = nil,
                canStar: Bool? = nil,
                canExport: Bool? = nil
            ) {
                self.id = id
                self.title = title
                self.description = description
                self.startDate = startDate
                self.photos = photos
                self.photoIds = photoIds
                self.starred = starred
                self.liked = liked
                self.canLike = canLike
                self.canEdit = canEdit
                self.canComment = canComment
                self.canStar = canStar
                self.canExport = canExport
            }
        }

        public struct FileItem: Decodable, Equatable, Sendable {
            public let id: String
            public let title: String?
            public let description: String?
            public let startDate: String?
            public let assets: [MBFileAsset]
            public let assetIds: [String]?
            public let starred: Bool?
            public let liked: Bool?
            public let canLike: Bool?
            public let canEdit: Bool?
            public let canComment: Bool?
            public let canStar: Bool?
            public let canExport: Bool?

            public init(
                id: String,
                title: String? = nil,
                description: String? = nil,
                startDate: String? = nil,
                assets: [MBFileAsset] = [],
                assetIds: [String]? = nil,
                starred: Bool? = nil,
                liked: Bool? = nil,
                canLike: Bool? = nil,
                canEdit: Bool? = nil,
                canComment: Bool? = nil,
                canStar: Bool? = nil,
                canExport: Bool? = nil
            ) {
                self.id = id
                self.title = title
                self.description = description
                self.startDate = startDate
                self.assets = assets
                self.assetIds = assetIds
                self.starred = starred
                self.liked = liked
                self.canLike = canLike
                self.canEdit = canEdit
                self.canComment = canComment
                self.canStar = canStar
                self.canExport = canExport
            }
        }

        public struct WebsiteItem: Decodable, Equatable, Sendable {
            public let id: String
            public let title: String?
            public let description: String?
            public let startDate: String?
            public let urls: [String]
            public let starred: Bool?
            public let liked: Bool?
            public let canLike: Bool?
            public let canEdit: Bool?
            public let canComment: Bool?
            public let canStar: Bool?
            public let canExport: Bool?

            public init(
                id: String,
                title: String? = nil,
                description: String? = nil,
                startDate: String? = nil,
                urls: [String] = [],
                starred: Bool? = nil,
                liked: Bool? = nil,
                canLike: Bool? = nil,
                canEdit: Bool? = nil,
                canComment: Bool? = nil,
                canStar: Bool? = nil,
                canExport: Bool? = nil
            ) {
                self.id = id
                self.title = title
                self.description = description
                self.startDate = startDate
                self.urls = urls
                self.starred = starred
                self.liked = liked
                self.canLike = canLike
                self.canEdit = canEdit
                self.canComment = canComment
                self.canStar = canStar
                self.canExport = canExport
            }
        }

        public typealias VideoItem = WebsiteItem

        public struct ReflectionItem: Decodable, Equatable, Sendable {
            public let id: String
            public let title: String?
            public let description: String?
            public let startDate: String?
            public let starred: Bool?
            public let liked: Bool?
            public let canLike: Bool?
            public let canEdit: Bool?
            public let canComment: Bool?
            public let canStar: Bool?
            public let canExport: Bool?

            public init(
                id: String,
                title: String? = nil,
                description: String? = nil,
                startDate: String? = nil,
                starred: Bool? = nil,
                liked: Bool? = nil,
                canLike: Bool? = nil,
                canEdit: Bool? = nil,
                canComment: Bool? = nil,
                canStar: Bool? = nil,
                canExport: Bool? = nil
            ) {
                self.id = id
                self.title = title
                self.description = description
                self.startDate = startDate
                self.starred = starred
                self.liked = liked
                self.canLike = canLike
                self.canEdit = canEdit
                self.canComment = canComment
                self.canStar = canStar
                self.canExport = canExport
            }
        }

        public struct EventItem: Decodable, Equatable, Sendable {
            public let id: String
            public let title: String?
            public let description: String?
            public let startDate: String?
            public let event: Event
            public let urls: [String]

            public let starred: Bool?
            public let liked: Bool?
            public let canLike: Bool?
            public let canEdit: Bool?
            public let canComment: Bool?
            public let canStar: Bool?
            public let canExport: Bool?

            public init(
                id: String,
                title: String? = nil,
                description: String? = nil,
                startDate: String? = nil,
                event: Event,
                urls: [String] = [],
                starred: Bool? = nil,
                liked: Bool? = nil,
                canLike: Bool? = nil,
                canEdit: Bool? = nil,
                canComment: Bool? = nil,
                canStar: Bool? = nil,
                canExport: Bool? = nil
            ) {
                self.id = id
                self.title = title
                self.description = description
                self.startDate = startDate
                self.event = event
                self.urls = urls
                self.starred = starred
                self.liked = liked
                self.canLike = canLike
                self.canEdit = canEdit
                self.canComment = canComment
                self.canStar = canStar
                self.canExport = canExport
            }
        }

        public struct Event: Decodable, Equatable, Sendable {
            public let id: String?
            public let name: String?
            public let type: String?
            public let groupID: String?
            public let startAt: String?
            public let category: String?
            public let groupName: String?
            public let groupType: String?
            public let bgcolor: String?
            public let fgcolor: String?
            public let allDay: Bool?
            public let txtcolor: String?
            public let dropboxID: String?
            public let gid: String?

            public init(
                id: String? = nil,
                name: String? = nil,
                type: String? = nil,
                groupID: String? = nil,
                startAt: String? = nil,
                category: String? = nil,
                groupName: String? = nil,
                groupType: String? = nil,
                bgcolor: String? = nil,
                fgcolor: String? = nil,
                allDay: Bool? = nil,
                txtcolor: String? = nil,
                dropboxID: String? = nil,
                gid: String? = nil
            ) {
                self.id = id
                self.name = name
                self.type = type
                self.groupID = groupID
                self.startAt = startAt
                self.category = category
                self.groupName = groupName
                self.groupType = groupType
                self.bgcolor = bgcolor
                self.fgcolor = fgcolor
                self.allDay = allDay
                self.txtcolor = txtcolor
                self.dropboxID = dropboxID
                self.gid = gid
            }

            private enum CodingKeys: String, CodingKey {
                case id
                case name
                case type
                case groupID = "group_id"
                case startAt = "start_at"
                case bgcolor
                case fgcolor
                case allDay = "all_day"
                case txtcolor
                case category
                case groupName = "group_name"
                case groupType = "group_type"
                case dropboxID = "dropbox_id"
                case gid = "gid"
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)

                let decodedID = try? container.decode(String.self, forKey: .id)
                let fallbackID = try? MBModelCoding.decodeOptionalStringID(from: container, forKey: .id)
                id = decodedID ?? fallbackID

                name = try container.decodeIfPresent(String.self, forKey: .name)
                type = try container.decodeIfPresent(String.self, forKey: .type)
                let decodedGroupID = try? container.decode(String.self, forKey: .groupID)
                let fallbackGroupID = try? MBModelCoding.decodeOptionalStringID(from: container, forKey: .groupID)
                groupID = decodedGroupID ?? fallbackGroupID
                startAt = try container.decodeIfPresent(String.self, forKey: .startAt)
                bgcolor = try container.decodeIfPresent(String.self, forKey: .bgcolor)
                fgcolor = try container.decodeIfPresent(String.self, forKey: .fgcolor)
                allDay = try container.decodeIfPresent(Bool.self, forKey: .allDay)
                txtcolor = try container.decodeIfPresent(String.self, forKey: .txtcolor)
                category = try container.decodeIfPresent(String.self, forKey: .category)
                groupName = try container.decodeIfPresent(String.self, forKey: .groupName)
                groupType = try container.decodeIfPresent(String.self, forKey: .groupType)
                let decodedDropboxID = try? container.decode(String.self, forKey: .dropboxID)
                let fallbackDropboxID = try? MBModelCoding.decodeOptionalStringID(from: container, forKey: .dropboxID)
                dropboxID = decodedDropboxID ?? fallbackDropboxID
                gid = try container.decodeIfPresent(String.self, forKey: .gid)
            }
        }

        public struct Preset: Decodable, Equatable, Sendable {
            public let id: String
            public let type: String?
            public let colors: [String]

            public init(id: String, type: String? = nil, colors: [String] = []) {
                self.id = id
                self.type = type
                self.colors = colors
            }

            private enum CodingKeys: String, CodingKey {
                case id
                case type
                case properties
            }

            private struct Properties: Decodable {
                let colors: [String]
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                id = try MBModelCoding.decodeStringID(from: container, forKey: .id)
                type = try container.decodeIfPresent(String.self, forKey: .type)
                let properties = try container.decodeIfPresent(Properties.self, forKey: .properties)
                colors = properties?.colors ?? []
            }
        }

        public struct Photo: Decodable, Equatable, Sendable, Identifiable {
            public let id: String
            public let filename: String
            public let url: String?
            public let versions: PhotoVersions?
            public let uploadedAt: String?

            public init(
                id: String,
                filename: String,
                url: String? = nil,
                versions: PhotoVersions? = nil,
                uploadedAt: String? = nil
            ) {
                self.id = id
                self.filename = filename
                self.url = url
                self.versions = versions
                self.uploadedAt = uploadedAt
            }

            private enum CodingKeys: String, CodingKey {
                case id
                case filename
                case url
                case versions
                case uploadedAt = "uploaded_at"
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                id = try MBModelCoding.decodeStringID(from: container, forKey: .id)
                filename = try container.decode(String.self, forKey: .filename)
                url = try container.decodeIfPresent(String.self, forKey: .url)
                versions = try container.decodeIfPresent(PhotoVersions.self, forKey: .versions)
                uploadedAt = try container.decodeIfPresent(String.self, forKey: .uploadedAt)
            }
        }

        public struct PhotoVersions: Decodable, Equatable, Sendable {
            public let thumb: String?
            public let square: String?
            public let tiny: String?

            public init(thumb: String? = nil, square: String? = nil, tiny: String? = nil) {
                self.thumb = thumb
                self.square = square
                self.tiny = tiny
            }

            private enum CodingKeys: String, CodingKey {
                case thumb
                case square
                case tiny
            }
        }

        public struct Author: Decodable, Equatable, Sendable {
            public let id: String?
            public let fullName: String?
            public let name: String?
            public let labels: [String]

            public var displayName: String? {
                fullName ?? name
            }

            public init(
                id: String? = nil,
                fullName: String? = nil,
                name: String? = nil,
                labels: [String] = []
            ) {
                self.id = id
                self.fullName = fullName
                self.name = name
                self.labels = labels
            }

            private enum CodingKeys: String, CodingKey {
                case id
                case fullName = "full_name"
                case name
                case labels
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                id = try? MBModelCoding.decodeOptionalStringID(from: container, forKey: .id)
                fullName = try container.decodeIfPresent(String.self, forKey: .fullName)
                name = try container.decodeIfPresent(String.self, forKey: .name)
                labels = TimelineItem.decodeLabelValues(
                    from: container,
                    forKey: Author.CodingKeys.labels
                )
            }
        }

        public struct AttributedStudent: Decodable, Equatable, Sendable, Identifiable {
            public let id: String
            public let displayName: String
            public let avatarURL: URL?

            public init(
                id: String,
                displayName: String,
                avatarURL: URL? = nil
            ) {
                self.id = id
                self.displayName = displayName
                self.avatarURL = avatarURL
            }

            private enum CodingKeys: String, CodingKey {
                case id
                case studentID = "student_id"
                case childID = "child_id"
                case userID = "user_id"
                case fullName = "full_name"
                case displayName = "display_name"
                case name
                case avatarURL = "avatar_url"
                case photoURL = "photo_url"
                case user
                case child
                case student
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)

                if let nested = try? container.decode(AttributedStudent.self, forKey: .user) {
                    self = nested
                    return
                }

                if let nested = try? container.decode(AttributedStudent.self, forKey: .child) {
                    self = nested
                    return
                }

                if let nested = try? container.decode(AttributedStudent.self, forKey: .student) {
                    self = nested
                    return
                }

                let decodedID = try? MBModelCoding.decodeOptionalStringID(from: container, forKey: .id)
                let decodedStudentID = try? MBModelCoding.decodeOptionalStringID(from: container, forKey: .studentID)
                let decodedChildID = try? MBModelCoding.decodeOptionalStringID(from: container, forKey: .childID)
                let decodedUserID = try? MBModelCoding.decodeOptionalStringID(from: container, forKey: .userID)
                id = decodedStudentID ?? decodedChildID ?? decodedID ?? decodedUserID ?? ""

                displayName = try container.decodeIfPresent(String.self, forKey: .fullName)
                    ?? container.decodeIfPresent(String.self, forKey: .displayName)
                    ?? container.decodeIfPresent(String.self, forKey: .name)
                    ?? ""

                avatarURL = try container.decodeIfPresent(URL.self, forKey: .avatarURL)
                    ?? container.decodeIfPresent(URL.self, forKey: .photoURL)
            }
        }

        private static func decodeLabelValues<C: CodingKey>(
            from container: KeyedDecodingContainer<C>,
            forKey key: C
        ) -> [String] {
            guard container.contains(key) else { return [] }
            if let singleValue = try? container.decode(DecodableLabelValue.self, forKey: key),
               let value = singleValue.value {
                return [value]
            }

            if let values = (try? container.decodeIfPresent([DecodableLabelValue].self, forKey: key)) {
                return values.compactMap { $0.value }
            }

            return []
        }

        private static func decodeAttributedStudents<C: CodingKey>(
            from container: KeyedDecodingContainer<C>,
            forKeys keys: [C]
        ) -> [AttributedStudent] {
            for key in keys where container.contains(key) {
                if let students = try? container.decode([AttributedStudent].self, forKey: key) {
                    return students.filter { $0.id.isEmpty == false }
                }

                if let student = try? container.decode(AttributedStudent.self, forKey: key),
                   student.id.isEmpty == false {
                    return [student]
                }
            }

            return []
        }

        private struct DecodableLabelValue: Decodable {
            let value: String?

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let rawString = try? container.decode(String.self) {
                    let trimmed = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
                    value = trimmed.isEmpty ? nil : trimmed
                    return
                }

                if let label = try? container.decode(Label.self) {
                    let rawTitle = label.title ?? label.name
                    let trimmed = rawTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
                    value = trimmed?.isEmpty == true ? nil : trimmed
                    return
                }

                value = nil
            }
        }

        private struct Label: Decodable {
            let title: String?
            let name: String?
        }
    }

}
