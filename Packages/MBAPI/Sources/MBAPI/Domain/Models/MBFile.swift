import Foundation

public struct MBFile: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let itemType: MBFileItemType
    public let item: MBFileItem

    public init(asset: MBFileAsset) {
        self.id = asset.id
        self.itemType = .asset
        self.item = .asset(asset)
    }

    public init(folder: MBFileFolder) {
        self.id = folder.id
        self.itemType = .folder
        self.item = .folder(folder)
    }

    public var asset: MBFileAsset? {
        switch item {
        case .asset(let asset):
            asset
        default:
            nil
        }
    }

    public var folder: MBFileFolder? {
        switch item {
        case .folder(let folder):
            folder
        default:
            nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case itemType = "item_type"
        case item
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let rawType = try container.decode(String.self, forKey: .itemType)
        var decodedType = MBFileItemType(rawValue: rawType) ?? .unknown
        let decodedItem: MBFileItem

        switch decodedType {
        case .asset:
            decodedItem = .asset(try container.decode(MBFileAsset.self, forKey: .item))
        case .folder:
            decodedItem = .folder(try container.decode(MBFileFolder.self, forKey: .item))
        case .unknown:
            if let asset = try? container.decode(MBFileAsset.self, forKey: .item) {
                decodedType = .asset
                decodedItem = .asset(asset)
            } else if let folder = try? container.decode(MBFileFolder.self, forKey: .item) {
                decodedType = .folder
                decodedItem = .folder(folder)
            } else {
                decodedType = .folder
                decodedItem = .folder(MBFileFolder(id: "0", name: "", updatedAt: nil))
            }
        }

        itemType = decodedType
        item = decodedItem

        switch item {
        case .asset(let asset):
            id = asset.id
        case .folder(let folder):
            id = folder.id
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(itemType, forKey: .itemType)
        switch item {
        case .asset(let asset):
            try container.encode(asset, forKey: .item)
        case .folder(let folder):
            try container.encode(folder, forKey: .item)
        }
    }

    public enum MBFileItem: Codable, Equatable, Sendable {
        case asset(MBFileAsset)
        case folder(MBFileFolder)
    }
}

public enum MBFileItemType: String, Codable, Equatable, Sendable {
    case asset = "Asset"
    case folder = "Folder"
    case unknown = ""
}

public struct MBFileAsset: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let gid: String?
    public let filename: String
    public let filesize: String?
    public let filetype: String?
    public let url: URL?
    public let uploadedAt: String?
    public let canEdit: Bool?
    public let canDelete: Bool?
    public let category: MBFileCategory?

    public init(
        id: String,
        gid: String? = nil,
        filename: String,
        filesize: String? = nil,
        filetype: String? = nil,
        url: URL? = nil,
        uploadedAt: String? = nil,
        canEdit: Bool? = nil,
        canDelete: Bool? = nil,
        category: MBFileCategory? = nil
    ) {
        self.id = id
        self.gid = gid
        self.filename = filename
        self.filesize = filesize
        self.filetype = filetype
        self.url = url
        self.uploadedAt = uploadedAt
        self.canEdit = canEdit
        self.canDelete = canDelete
        self.category = category
    }

    public var displayName: String { filename }
    public var info: String { [uploadedAt, filesize].compactMap { $0 }.joined(separator: " • ") }

    private enum CodingKeys: String, CodingKey {
        case id
        case gid
        case filename
        case filesize
        case filetype
        case url
        case uploadedAt = "uploaded_at"
        case canEdit = "can_edit"
        case canDelete = "can_delete"
        case category = "asset_type"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try MBModelCoding.decodeStringID(from: container, forKey: .id)
        gid = try container.decodeIfPresent(String.self, forKey: .gid)
        filename = try container.decode(String.self, forKey: .filename)
        filesize = try container.decodeIfPresent(String.self, forKey: .filesize)
        filetype = try container.decodeIfPresent(String.self, forKey: .filetype)
        url = try container.decodeIfPresent(URL.self, forKey: .url)
        uploadedAt = try container.decodeIfPresent(String.self, forKey: .uploadedAt)
        canEdit = try container.decodeIfPresent(Bool.self, forKey: .canEdit)
        canDelete = try container.decodeIfPresent(Bool.self, forKey: .canDelete)
        category = try container.decodeIfPresent(MBFileCategory.self, forKey: .category)
    }
}

public struct MBFileFolder: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let updatedAt: String?
    public let canEdit: Bool?
    public let canDelete: Bool?

    public init(id: String, name: String, updatedAt: String? = nil, canEdit: Bool? = nil, canDelete: Bool? = nil) {
        self.id = id
        self.name = name
        self.updatedAt = updatedAt
        self.canEdit = canEdit
        self.canDelete = canDelete
    }

    public var info: String { updatedAt ?? "" }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case updatedAt = "updated_at"
        case canEdit = "can_edit"
        case canDelete = "can_delete"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try MBModelCoding.decodeStringID(from: container, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        canEdit = try container.decodeIfPresent(Bool.self, forKey: .canEdit)
        canDelete = try container.decodeIfPresent(Bool.self, forKey: .canDelete)
    }
}

public struct MBFileCategory: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try MBModelCoding.decodeStringID(from: container, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
    }
}
