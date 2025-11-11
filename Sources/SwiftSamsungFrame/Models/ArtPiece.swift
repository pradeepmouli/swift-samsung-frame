// ArtPiece - Represents artwork for Frame TVs
// Contains art metadata and display settings

import Foundation

/// Represents artwork available on Frame TVs
public struct ArtPiece: Sendable, Identifiable, Hashable, Codable {
    /// Unique art identifier
    public let id: String
    
    /// Art piece title
    public let title: String
    
    /// Type (preloaded, user-uploaded, store-purchased)
    public let category: ArtCategory
    
    /// Thumbnail image URL
    public let thumbnailURL: URL?
    
    /// Format (JPEG, PNG)
    public let imageType: ImageType
    
    /// Frame matte configuration
    public let matteStyle: MatteStyle?
    
    /// Applied photo filter
    public let filter: PhotoFilter?
    
    /// When uploaded (user content only)
    public let uploadDate: Date?
    
    /// Image size in bytes
    public let fileSize: Int?
    
    /// Initialize a new art piece
    /// - Parameters:
    ///   - id: Unique art identifier
    ///   - title: Art piece title
    ///   - category: Art category
    ///   - thumbnailURL: Thumbnail image URL
    ///   - imageType: Image format
    ///   - matteStyle: Frame matte configuration
    ///   - filter: Applied photo filter
    ///   - uploadDate: Upload timestamp
    ///   - fileSize: Image size in bytes
    public init(
        id: String,
        title: String,
        category: ArtCategory,
        thumbnailURL: URL? = nil,
        imageType: ImageType = .jpeg,
        matteStyle: MatteStyle? = nil,
        filter: PhotoFilter? = nil,
        uploadDate: Date? = nil,
        fileSize: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.thumbnailURL = thumbnailURL
        self.imageType = imageType
        self.matteStyle = matteStyle
        self.filter = filter
        self.uploadDate = uploadDate
        self.fileSize = fileSize
    }
}

// MARK: - Example for Testing

extension ArtPiece {
    /// Example art piece for testing purposes
    public static let example = ArtPiece(
        id: "SAM-F0206",
        title: "Coastal Sunset",
        category: .preloaded,
        thumbnailURL: URL(string: "https://example.com/thumbnail.jpg"),
        imageType: .jpeg,
        matteStyle: .modernBeige,
        filter: PhotoFilter.none,
        uploadDate: nil,
        fileSize: 1024000
    )
}
