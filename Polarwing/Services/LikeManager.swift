//
//  LikeManager.swift
//  Polarwing
//
//  Created on 2025-11-24.
//

import Foundation
import Combine

// 点赞管理器 - 用于在不同视图间同步点赞状态
class LikeManager: ObservableObject {
    static let shared = LikeManager()
    
    // 存储已点赞的帖子ID和点赞数
    @Published private(set) var likedPosts: [String: Int] = [:] // [postId: likeCount]
    
    private init() {}
    
    // 检查帖子是否已点赞
    func isLiked(postId: String) -> Bool {
        return likedPosts[postId] != nil
    }
    
    // 获取帖子的点赞数
    func getLikeCount(postId: String, defaultCount: Int) -> Int {
        return likedPosts[postId] ?? defaultCount
    }
    
    // 更新点赞状态
    func updateLike(postId: String, isLiked: Bool, likeCount: Int) {
        if isLiked {
            likedPosts[postId] = likeCount
        } else {
            likedPosts.removeValue(forKey: postId)
        }
    }
}
