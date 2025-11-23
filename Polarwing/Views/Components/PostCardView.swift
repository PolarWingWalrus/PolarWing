//
//  PostCardView.swift
//  Polarwing
//
//  Created on 2025-11-22.
//

import SwiftUI

struct PostCardView: View {
    let post: Post
    let showUsername: Bool
    @State private var imageData: UIImage?
    @State private var isLoadingImage = false
    
    init(post: Post, showUsername: Bool = true) {
        self.post = post
        self.showUsername = showUsername
    }
    
    var displayTitle: String {
        post.title ?? post.contentTitle ?? "无标题"
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                // 背景图片或占位符
                if let image = imageData {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else if isLoadingImage {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            ProgressView()
                        )
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.gray.opacity(0.3))
                        )
                }
                
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                    startPoint: .center,
                    endPoint: .bottom
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        if showUsername {
                            HStack(spacing: 4) {
                                Image(systemName: post.userAvatar)
                                    .font(.caption2)
                                Text(post.username)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                            Text("\(post.likes)")
                                .font(.caption2)
                        }
                    }
                    .foregroundColor(.white.opacity(0.9))
                }
                .padding(8)
            }
        }
        .aspectRatio(0.75, contentMode: .fit)
        .cornerRadius(8)
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        // 获取图片 URL（优先使用 mediaUrls，其次使用 contentMediaUrls）
        let mediaUrls = post.mediaUrls ?? post.contentMediaUrls
        guard let urlString = mediaUrls?.first,
              let url = URL(string: urlString) else {
            return
        }
        
        // 跳过系统图标名称
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            isLoadingImage = true
            
            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let image = UIImage(data: data) {
                        await MainActor.run {
                            self.imageData = image
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
}
