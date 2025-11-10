import Foundation

/// Represents an art piece on a Frame TV
public struct ArtPiece: Sendable, Identifiable, Hashable, Codable {
    /// Unique art ID
    public let id: String
    
    /// Art title
    public let title: String
    
    /// Art category
    public let category: ArtCategory
    
    /// Thumbnail URL
    public let thumbnailURL: URL?
    
    /// Full image URL
    public let imageURL: URL?
    
    /// Image type (JPEG, PNG)
    public let imageType: ImageType
    
    /// Matte style applied to the art
    public let matteStyle: MatteStyle
    
    /// Photo filter applied to the art
    public let filter: PhotoFilter
    
    /// Whether this is a custom uploaded image
    public let isCustom: Bool
    
    /// Creates a new art piece
    /// - Parameters:
    ///   - id: Art ID
    ///   - title: Art title
    ///   - category: Art category
    ///   - thumbnailURL: Thumbnail URL
    ///   - imageURL: Full image URL
    ///   - imageType: Image type (default: jpeg)
    ///   - matteStyle: Matte style (default: none)
    ///   - filter: Photo filter (default: none)
    ///   - isCustom: Whether this is custom art (default: false)
    public init(
        id: String,
        title: String,
        category: ArtCategory = .unknown,
        thumbnailURL: URL? = nil,
        imageURL: URL? = nil,
        imageType: ImageType = .jpeg,
        matteStyle: MatteStyle = .none,
        filter: PhotoFilter = .none,
        isCustom: Bool = false
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.thumbnailURL = thumbnailURL
        self.imageURL = imageURL
        self.imageType = imageType
        self.matteStyle = matteStyle
        self.filter = filter
        self.isCustom = isCustom
    }
}
