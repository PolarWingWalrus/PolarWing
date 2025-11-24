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
    @State private var authorProfile: ProfileResponse?
    @State private var authorAvatarImage: UIImage?
    @State private var imageOrientation: ImageOrientation = .portrait
    
    enum ImageOrientation {
        case portrait   // 竖屏或正方形
        case landscape  // 横屏
    }
    
    // 点赞功能
    @State private var isLiked = false
    @State private var likeCount: Int
    @State private var isLiking = false
    @StateObject private var p256Signer = P256Signer.shared
    @StateObject private var likeManager = LikeManager.shared
    
    init(post: Post, showUsername: Bool = true) {
        self.post = post
        self.showUsername = showUsername
        _likeCount = State(initialValue: post.likeCount)
        _isLiked = State(initialValue: post.isLiked)
    }
    
    var displayTitle: String {
        post.title ?? post.contentTitle ?? "无标题"
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
    
    var hasImage: Bool {
        let mediaUrls = post.mediaUrls ?? post.contentMediaUrls
        if let urlString = mediaUrls?.first,
           (urlString.hasPrefix("http://") || urlString.hasPrefix("https://")) {
            return true
        }
        return false
    }
    
    // 根据图片方向使用固定的宽高比
    var cardAspectRatio: CGFloat {
        if hasImage {
            switch imageOrientation {
            case .landscape:
                // 横屏图片：宽度 / 高度 = 4:3 ≈ 1.33
                return 1.33
            case .portrait:
                // 竖屏或正方形图片：宽度 / 高度 = 3:4 = 0.75
                return 0.75
            }
        } else {
            // 纯文本时使用更小的高度，根据标题长度动态调整
            let titleLength = displayTitle.count
            if titleLength < 15 {
                return 1.8  // 很短的标题，最矮的卡片
            } else if titleLength < 30 {
                return 1.4  // 中等长度标题
            } else {
                return 1.0  // 较长标题
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 图片部分
            GeometryReader { geometry in
                ZStack(alignment: .center) {
                    if hasImage {
                        // 有图片时显示图片或加载状态
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
                        }
                    } else {
                        // 纯文本时使用渐变背景
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 172/255, green: 237/255, blue: 228/255).opacity(0.3),
                                Color(red: 172/255, green: 237/255, blue: 228/255).opacity(0.6)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        
                        // 纯文本时在图片区域显示标题
                        VStack {
                            Text(displayTitle)
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.black.opacity(0.85))
                                .lineLimit(4)
                                .multilineTextAlignment(.leading)
                                .padding(12)
                            Spacer()
                        }
                    }
                }
            }
            .aspectRatio(cardAspectRatio, contentMode: .fit)
            .cornerRadius(8)
            
            // 文字和点赞信息部分（显示在图片下方）
            if hasImage {
                VStack(alignment: .leading, spacing: 6) {
                    Text(displayTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        if showUsername {
                            HStack(spacing: 4) {
                                // 显示用户头像
                                if let avatarImage = authorAvatarImage {
                                    Image(uiImage: avatarImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 16, height: 16)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: post.userAvatar)
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                Text(displayUsername)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: toggleLike) {
                            HStack(spacing: 4) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.caption2)
                                    .foregroundColor(isLiked ? .red : .white.opacity(0.7))
                                Text("\(likeCount)")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .disabled(isLiking || isLiked)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            } else {
                // 纯文本卡片的底部信息
                HStack(spacing: 8) {
                    if showUsername {
                        HStack(spacing: 4) {
                            if let avatarImage = authorAvatarImage {
                                Image(uiImage: avatarImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 16, height: 16)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: post.userAvatar)
                                    .font(.caption2)
                                    .foregroundColor(.black.opacity(0.6))
                            }
                            Text(displayUsername)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.black.opacity(0.6))
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: toggleLike) {
                        HStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.caption2)
                                .foregroundColor(isLiked ? .red : .black.opacity(0.6))
                            Text("\(likeCount)")
                                .font(.caption2)
                                .foregroundColor(.black.opacity(0.6))
                        }
                    }
                    .disabled(isLiking || isLiked)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .onAppear {
            if hasImage {
                loadImage()
            }
            loadAuthorProfile()
            // 从LikeManager加载点赞状态
            isLiked = likeManager.isLiked(postId: post.id)
            likeCount = likeManager.getLikeCount(postId: post.id, defaultCount: post.likeCount)
        }
        .onReceive(likeManager.$likedPosts) { likedPosts in
            // 监听点赞状态变化
            isLiked = likedPosts[post.id] != nil
            if let count = likedPosts[post.id] {
                likeCount = count
            }
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
            // 先尝试从缓存加载
            if let cachedImage = CacheManager.shared.loadImage(for: urlString) {
                self.imageData = cachedImage
                self.imageOrientation = detectImageOrientation(cachedImage)
                return
            }
            
            isLoadingImage = true
            
            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let image = UIImage(data: data) {
                        // 检测图片方向
                        let orientation = detectImageOrientation(image)
                        
                        await MainActor.run {
                            self.imageData = image
                            self.imageOrientation = orientation
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
    
    // 检测图片方向
    private func detectImageOrientation(_ image: UIImage) -> ImageOrientation {
        let width = image.size.width
        let height = image.size.height
        
        // 横屏：宽度明显大于高度（宽高比 > 1.2）
        if width > height * 1.2 {
            return .landscape
        } else {
            // 竖屏或正方形（包括宽高比 <= 1.2 的情况）
            return .portrait
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
