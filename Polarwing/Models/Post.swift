//
//  Post.swift
//  Polarwing
//
//  Created on 2025-11-22.
//

import Foundation

struct Post: Identifiable, Codable {
    let id: String
    let author: String
    let blobId: String?
    let tags: [String]
    let visibility: String
    let storageType: String
    let txDigest: String?
    let likeCount: Int
    let commentCount: Int
    let createdAt: String
    let updatedAt: String
    
    // Optional fields for DB storage
    var contentTitle: String?
    var contentText: String?
    var contentMediaUrls: [String]?
    
    // Fields populated from API /posts/{id}/content
    var title: String?
    var content: String?
    var mediaUrls: [String]?
    
    // UI helper properties
    var userId: String { author }
    var username: String { 
        // Extract short address for display
        let prefix = author.prefix(6)
        let suffix = author.suffix(4)
        return "\(prefix)...\(suffix)"
    }
    var userAvatar: String { "person.circle.fill" }
    var imageUrl: String { 
        // Use first media URL or system icon
        if let urls = mediaUrls ?? contentMediaUrls, let first = urls.first {
            return first
        }
        return "photo"
    }
    var likes: Int { likeCount }
    var comments: Int { commentCount }
    
    enum CodingKeys: String, CodingKey {
        case id, author
        case blobId = "blob_id"
        case tags, visibility
        case storageType = "storage_type"
        case txDigest = "tx_digest"
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case contentTitle = "content_title"
        case contentText = "content_text"
        case contentMediaUrls = "content_media_urls"
        case title, content
        case mediaUrls = "media_urls"
    }
    
    init(id: String = UUID().uuidString,
         author: String,
         blobId: String? = nil,
         tags: [String] = [],
         visibility: String = "public",
         storageType: String = "db",
         txDigest: String? = nil,
         likeCount: Int = 0,
         commentCount: Int = 0,
         createdAt: String = ISO8601DateFormatter().string(from: Date()),
         updatedAt: String = ISO8601DateFormatter().string(from: Date()),
         contentTitle: String? = nil,
         contentText: String? = nil,
         contentMediaUrls: [String]? = nil,
         title: String? = nil,
         content: String? = nil,
         mediaUrls: [String]? = nil) {
        self.id = id
        self.author = author
        self.blobId = blobId
        self.tags = tags
        self.visibility = visibility
        self.storageType = storageType
        self.txDigest = txDigest
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.contentTitle = contentTitle
        self.contentText = contentText
        self.contentMediaUrls = contentMediaUrls
        self.title = title
        self.content = content
        self.mediaUrls = mediaUrls
    }
}
