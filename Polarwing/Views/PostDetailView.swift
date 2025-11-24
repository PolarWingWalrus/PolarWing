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
    @State private var authorProfile: ProfileResponse?
    @State private var authorAvatarImage: UIImage?
    
    // 隐藏的测试功能
    @State private var avatarTapCount = 0
    @State private var showDebugInfo = false
    
    // 点赞功能
    @State private var isLiked = false
    @State private var likeCount: Int
    @State private var isLiking = false
    @StateObject private var p256Signer = P256Signer.shared
    @StateObject private var likeManager = LikeManager.shared
    
    init(post: Post) {
        self.post = post
        _likeCount = State(initialValue: post.likeCount)
        _isLiked = State(initialValue: post.isLiked)
    }
    
    var displayTitle: String {
        post.title ?? post.contentTitle ?? "无标题"
    }
    
    var displayContent: String {
        post.content ?? post.contentText ?? ""
    }
    
    var displayUsername: String {
        if let profile = authorProfile {
            let nickname = profile.nickname
            if !nickname.isEmpty && nickname != "TBD" {
                return nickname
            }
        }
        return post.username
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
                        // 显示用户头像
                        Group {
                            if let avatarImage = authorAvatarImage {
                                Image(uiImage: avatarImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: post.userAvatar)
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.blue)
                            }
                        }
                        .onTapGesture {
                            avatarTapCount += 1
                            if avatarTapCount >= 3 {
                                showDebugInfo = true
                                avatarTapCount = 0
                            }
                            
                            // 2秒后重置计数
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                if avatarTapCount > 0 {
                                    avatarTapCount = 0
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayUsername)
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
                        Button(action: toggleLike) {
                            HStack(spacing: 6) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.title3)
                                    .foregroundColor(isLiked ? .red : .gray)
                                Text("\(likeCount)")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .disabled(isLiking || isLiked)
                        
                        HStack(spacing: 6) {
                            Image(systemName: "bubble.right")
                                .font(.title3)
                            Text("\(post.comments)")
                                .font(.subheadline)
                        }
                        .foregroundColor(.gray)
                        
                        Spacer()
                    }
                }
                .padding(.horizontal)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onAppear {
            loadPostImage()
            loadAuthorProfile()
            // 从LikeManager加载点赞状态
            isLiked = likeManager.isLiked(postId: post.id)
            likeCount = likeManager.getLikeCount(postId: post.id, defaultCount: post.likeCount)
        }
        .alert("🔍 调试信息", isPresented: $showDebugInfo) {
            Button("复制帖子ID", role: .none) {
                UIPasteboard.general.string = post.id
            }
            Button("复制用户地址", role: .none) {
                UIPasteboard.general.string = post.author
            }
            Button("关闭", role: .cancel) {}
        } message: {
            VStack(alignment: .leading, spacing: 8) {
                Text("📝 帖子ID:\n\(post.id)")
                Text("\n👤 用户地址:\n\(post.author)")
                Text("\n🔤 用户名:\n\(post.username)")
                Text("\n📅 创建时间:\n\(post.createdAt)")
                if let mediaUrls = post.mediaUrls ?? post.contentMediaUrls, !mediaUrls.isEmpty {
                    Text("\n🖼️ 媒体URL:\n\(mediaUrls.joined(separator: "\n"))")
                }
            }
        }
    }
    
    private func loadAuthorProfile() {
        // 如果已经有作者信息，跳过
        if authorProfile != nil {
            return
        }
        
        // 先尝试从缓存加载
        if let cachedProfile = CacheManager.shared.loadProfile(for: post.author) {
            self.authorProfile = cachedProfile
            
            // 尝试从缓存加载头像
            let avatarUrl = cachedProfile.avatarUrl
            if avatarUrl != "TBD" && !avatarUrl.isEmpty {
                if let cachedImage = CacheManager.shared.loadImage(for: avatarUrl) {
                    self.authorAvatarImage = cachedImage
                    return // 缓存命中，直接返回
                }
            }
        }
        
        Task {
            do {
                let profile = try await APIService.shared.getProfile(suiAddress: post.author)
                
                await MainActor.run {
                    self.authorProfile = profile
                    // 缓存用户资料
                    CacheManager.shared.saveProfile(profile, for: post.author)
                }
                
                // 加载头像图片
                let avatarUrl = profile.avatarUrl
                if avatarUrl != "TBD" && !avatarUrl.isEmpty,
                   let url = URL(string: avatarUrl) {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let image = UIImage(data: data) {
                        await MainActor.run {
                            self.authorAvatarImage = image
                            // 缓存头像图片
                            CacheManager.shared.saveImage(image, for: avatarUrl)
                        }
                    }
                }
            } catch {
                // 静默失败，使用默认显示
                print("⚠️ 获取作者信息失败 (\(post.author)): \(error.localizedDescription)")
            }
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
            // 先尝试从缓存加载
            if let cachedImage = CacheManager.shared.loadImage(for: urlString) {
                self.postImage = cachedImage
                return
            }
            
            isLoadingImage = true
            
            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let image = UIImage(data: data) {
                        await MainActor.run {
                            self.postImage = image
                            self.isLoadingImage = false
                            // 缓存图片
                            CacheManager.shared.saveImage(image, for: urlString)
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
    
    private func toggleLike() {
        guard !isLiking,
              !isLiked, // 已点赞则不允许操作(取消点赞功能暂未实现)
              let suiAddress = UserDefaults.standard.string(forKey: "suiAddress"),
              let publicKey = p256Signer.publicKey else {
            return
        }
        
        isLiking = true
        
        // 创建签名数据
        let action = "like"
        let timestamp = Int(Date().timeIntervalSince1970)
        let nonce = Int.random(in: 1...Int.max)
        let message = "\(action)\(timestamp)\(nonce)"
        
        // 签名
        p256Signer.signMessage(message) { signResult in
            switch signResult {
            case .success(let signatureResult):
                Task {
                    do {
                        // 点赞
                        let response = try await APIService.shared.likePost(
                            postId: post.id,
                            suiAddress: suiAddress,
                            publicKey: publicKey.base64EncodedString(),
                            signature: signatureResult.signature.base64EncodedString(),
                            action: action,
                            timestamp: timestamp,
                            nonce: nonce
                        )
                        
                        await MainActor.run {
                            self.isLiked = true
                            self.likeCount = response.likeCount
                            self.isLiking = false
                            // 更新全局点赞状态
                            likeManager.updateLike(postId: post.id, isLiked: true, likeCount: response.likeCount)
                        }
                    } catch {
                        await MainActor.run {
                            self.isLiking = false
                            
                            // 检查是否是已点赞错误
                            let nsError = error as NSError
                            if nsError.domain == "APIService" && nsError.code == 409 {
                                // 已点赞，更新UI状态
                                print("ℹ️ 用户已点赞此帖子，更新UI状态")
                                self.isLiked = true
                                // 增加点赞数（如果本地还没增加）
                                if !likeManager.isLiked(postId: post.id) {
                                    self.likeCount += 1
                                }
                                likeManager.updateLike(postId: post.id, isLiked: true, likeCount: self.likeCount)
                            } else {
                                print("❌ 点赞操作失败: \(error.localizedDescription)")
                            }
                        }
                    }
                }
                
            case .failure(let error):
                isLiking = false
                print("❌ 签名失败: \(error.localizedDescription)")
            }
        }
    }
}
