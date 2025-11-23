//
//  PostDetailView.swift
//  Polarwing
//
//  Created on 2025-11-22.
//

import SwiftUI

struct PostDetailView: View {
    let post: Post
    @State private var postImage: UIImage?
    @State private var isLoadingImage = false
    
    var displayTitle: String {
        post.title ?? post.contentTitle ?? "无标题"
    }
    
    var displayContent: String {
        post.content ?? post.contentText ?? ""
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 帖子图片
                if let image = postImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                } else if isLoadingImage {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)
                        .overlay(
                            ProgressView()
                        )
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)
                        .foregroundColor(.gray.opacity(0.3))
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: post.userAvatar)
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(post.username)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text(timeAgoString(from: post.createdAt))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                    
                    Text(displayTitle)
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    if !displayContent.isEmpty {
                        Text(displayContent)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    
                    HStack(spacing: 24) {
                        HStack(spacing: 6) {
                            Image(systemName: "heart")
                                .font(.title3)
                            Text("\(post.likes)")
                                .font(.subheadline)
                        }
                        
                        HStack(spacing: 6) {
                            Image(systemName: "bubble.right")
                                .font(.title3)
                            Text("\(post.comments)")
                                .font(.subheadline)
                        }
                        
                        Spacer()
                    }
                    .foregroundColor(.gray)
                }
                .padding(.horizontal)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadPostImage()
        }
    }
    
    private func loadPostImage() {
        // 获取图片 URL
        let mediaUrls = post.mediaUrls ?? post.contentMediaUrls
        guard let urlString = mediaUrls?.first,
              let url = URL(string: urlString) else {
            return
        }
        
        // 只加载远程图片
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            isLoadingImage = true
            
            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let image = UIImage(data: data) {
                        await MainActor.run {
                            self.postImage = image
                            self.isLoadingImage = false
                        }
                    } else {
                        await MainActor.run {
                            self.isLoadingImage = false
                        }
                    }
                } catch {
                    print("❌ 加载图片失败 (\(urlString)): \(error.localizedDescription)")
                    await MainActor.run {
                        self.isLoadingImage = false
                    }
                }
            }
        }
    }
    
    private func timeAgoString(from dateString: String) -> String {
        // 解析 ISO 8601 日期字符串
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let seconds = Date().timeIntervalSince(date)
        
        if seconds < 60 {
            return "刚刚"
        } else if seconds < 3600 {
            return "\(Int(seconds / 60))分钟前"
        } else if seconds < 86400 {
            return "\(Int(seconds / 3600))小时前"
        } else {
            return "\(Int(seconds / 86400))天前"
        }
    }
}
