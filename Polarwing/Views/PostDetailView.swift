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
    @State private var imageTapCount = 0
    @State private var showBlobInfo = false
    
    // 点赞功能
    @State private var isLiked = false
    @State private var likeCount: Int
    @State private var isLiking = false
    @StateObject private var p256Signer = P256Signer.shared
    @StateObject private var likeManager = LikeManager.shared
    
    // 评论功能
    @State private var comments: [CommentResponse] = []
    @State private var isLoadingComments = false
    @State private var commentText = ""
    @State private var isPostingComment = false
    @State private var commentCount: Int
    @FocusState private var isCommentFieldFocused: Bool
    
    init(post: Post) {
        self.post = post
        _likeCount = State(initialValue: post.likeCount)
        _isLiked = State(initialValue: post.isLiked)
        _commentCount = State(initialValue: post.commentCount)
    }
    
    var displayTitle: String {
        post.title ?? post.contentTitle ?? "Untitled"
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
                        .onTapGesture {
                            imageTapCount += 1
                            if imageTapCount >= 3 {
                                showBlobInfo = true
                                imageTapCount = 0
                            }
                            
                            // 2秒后重置计数
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                if imageTapCount > 0 {
                                    imageTapCount = 0
                                }
                            }
                        }
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
                            Text("\(commentCount)")
                                .font(.subheadline)
                        }
                        .foregroundColor(.gray)
                        
                        Spacer()
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Comments section title
                    HStack {
                        Text("Comments")
                            .font(.headline)
                        
                        if isLoadingComments {
                            ProgressView()
                                .scaleEffect(0.8)
                                .padding(.leading, 8)
                        }
                        
                        Spacer()
                    }
                    .padding(.bottom, 8)
                    
                    // 评论列表
                    if comments.isEmpty && !isLoadingComments {
                        Text("No comments yet. Be the first to comment!")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        ForEach(comments, id: \.id) { comment in
                            CommentRowView(comment: comment)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .safeAreaInset(edge: .bottom) {
            // 发表评论输入框
            HStack(spacing: 12) {
                TextField("Write your comment...", text: $commentText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(20)
                    .lineLimit(1...5)
                    .focused($isCommentFieldFocused)
                
                Button(action: postComment) {
                    if isPostingComment {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(commentText.isEmpty ? .gray : Color(red: 172/255, green: 237/255, blue: 228/255))
                    }
                }
                .disabled(commentText.isEmpty || isPostingComment)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.95))
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onAppear {
            loadPostImage()
            loadAuthorProfile()
            loadComments()
            // 从LikeManager加载点赞状态
            isLiked = likeManager.isLiked(postId: post.id)
            likeCount = likeManager.getLikeCount(postId: post.id, defaultCount: post.likeCount)
        }
        .refreshable {
            // 下拉刷新时重新加载评论
            await refreshComments()
        }
        .alert("🔍 Debug Info", isPresented: $showDebugInfo) {
            Button("Copy Post ID", role: .none) {
                UIPasteboard.general.string = post.id
            }
            Button("Copy User Address", role: .none) {
                UIPasteboard.general.string = post.author
            }
            Button("Close", role: .cancel) {}
        } message: {
            VStack(alignment: .leading, spacing: 8) {
                Text("📝 Post ID:\n\(post.id)")
                Text("\n👤 User Address:\n\(post.author)")
                Text("\n🔤 Username:\n\(post.username)")
                Text("\n📅 Created At:\n\(post.createdAt)")
                if let mediaUrls = post.mediaUrls ?? post.contentMediaUrls, !mediaUrls.isEmpty {
                    Text("\n🖼️ Media URL:\n\(mediaUrls.joined(separator: "\n"))")
                }
            }
        }
        .alert("🗂️ Blob Info", isPresented: $showBlobInfo) {
            if let blobId = post.blobId, !blobId.isEmpty {
                Button("Copy Blob ID", role: .none) {
                    UIPasteboard.general.string = blobId
                }
                Button("Open in Walruscan", role: .none) {
                    openWalruscan(blobId: blobId)
                }
                Button("Close", role: .cancel) {}
            } else {
                Button("Close", role: .cancel) {}
            }
        } message: {
            if let blobId = post.blobId, !blobId.isEmpty {
                Text("🗂️ Blob ID:\n\(blobId)\n\nStorage Type: \(post.storageType)")
            } else {
                Text("📦 Storage Type: \(post.storageType)\n\nNo Blob ID available (content stored in database)")
            }
        }
    }
    
    private func openWalruscan(blobId: String) {
        let urlString = "https://walruscan.com/testnet/blob/\(blobId)"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
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
    
    private func loadComments() {
        guard let suiAddress = UserDefaults.standard.string(forKey: "suiAddress") else {
            return
        }
        
        // 只在没有评论时才显示加载状态
        if comments.isEmpty {
            isLoadingComments = true
        }
        
        Task {
            do {
                let commentsPage = try await APIService.shared.getComments(
                    postId: post.id,
                    page: 1,
                    pageSize: 50,
                    includeContent: true,
                    suiAddress: suiAddress
                )
                
                await MainActor.run {
                    self.comments = commentsPage.comments
                    self.commentCount = commentsPage.total
                    self.isLoadingComments = false
                    print("✅ 成功加载 \(commentsPage.comments.count) 条评论")
                }
            } catch {
                await MainActor.run {
                    self.isLoadingComments = false
                    print("❌ 加载评论失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func refreshComments() async {
        guard let suiAddress = UserDefaults.standard.string(forKey: "suiAddress") else {
            return
        }
        
        do {
            let commentsPage = try await APIService.shared.getComments(
                postId: post.id,
                page: 1,
                pageSize: 50,
                includeContent: true,
                suiAddress: suiAddress
            )
            
            await MainActor.run {
                self.comments = commentsPage.comments
                self.commentCount = commentsPage.total
                print("✅ 刷新成功: 加载 \(commentsPage.comments.count) 条评论")
            }
        } catch {
            print("❌ 刷新评论失败: \(error.localizedDescription)")
        }
    }
    
    private func postComment() {
        guard !commentText.isEmpty,
              let suiAddress = UserDefaults.standard.string(forKey: "suiAddress"),
              let publicKey = p256Signer.publicKey else {
            return
        }
        
        isPostingComment = true
        
        // 创建签名数据
        let action = "comment"
        let timestamp = Int(Date().timeIntervalSince1970)
        let nonce = Int.random(in: 1...Int.max)
        let message = "\(action)\(timestamp)\(nonce)"
        
        // 签名
        p256Signer.signMessage(message) { signResult in
            switch signResult {
            case .success(let signatureResult):
                Task {
                    do {
                        let savedCommentText = commentText // 保存评论文本
                        let comment = try await APIService.shared.createComment(
                            postId: post.id,
                            text: commentText,
                            storageType: "walrus",
                            suiAddress: suiAddress,
                            publicKey: publicKey.base64EncodedString(),
                            signature: signatureResult.signature.base64EncodedString(),
                            action: action,
                            timestamp: timestamp,
                            nonce: nonce
                        )
                        
                        await MainActor.run {
                            // 创建包含完整内容的评论对象
                            var fullComment = comment
                            // 如果 API 返回的评论没有内容文本，使用本地保存的文本
                            if fullComment.contentText == nil || fullComment.contentText?.isEmpty == true {
                                fullComment = CommentResponse(
                                    id: comment.id,
                                    postId: comment.postId,
                                    author: comment.author,
                                    blobId: comment.blobId,
                                    contentText: savedCommentText,
                                    storageType: comment.storageType,
                                    txDigest: comment.txDigest,
                                    createdAt: comment.createdAt
                                )
                            }
                            self.comments.insert(fullComment, at: 0)
                            self.commentCount += 1
                            self.commentText = ""
                            self.isPostingComment = false
                            self.isCommentFieldFocused = false
                            print("✅ 成功发表评论")
                        }
                    } catch {
                        await MainActor.run {
                            self.isPostingComment = false
                            print("❌ 发表评论失败: \(error.localizedDescription)")
                        }
                    }
                }
                
            case .failure(let error):
                isPostingComment = false
                print("❌ 签名失败: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - 评论行视图
struct CommentRowView: View {
    let comment: CommentResponse
    @State private var authorProfile: ProfileResponse?
    @State private var authorAvatarImage: UIImage?
    
    var displayUsername: String {
        if let profile = authorProfile {
            let nickname = profile.nickname
            if !nickname.isEmpty && nickname != "TBD" {
                return nickname
            }
        }
        // 显示缩短的地址
        let prefix = comment.author.prefix(6)
        let suffix = comment.author.suffix(4)
        return "\(prefix)...\(suffix)"
    }
    
    var displayText: String {
        comment.contentText ?? ""
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 用户头像
            Group {
                if let avatarImage = authorAvatarImage {
                    Image(uiImage: avatarImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 36, height: 36)
                        .foregroundColor(.gray)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(displayUsername)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text(timeAgoString(from: comment.createdAt))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Text(displayText)
                    .font(.body)
                    .foregroundColor(.white)
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            loadAuthorProfile()
        }
    }
    
    private func loadAuthorProfile() {
        // 先尝试从缓存加载
        if let cachedProfile = CacheManager.shared.loadProfile(for: comment.author) {
            self.authorProfile = cachedProfile
            
            // 尝试从缓存加载头像
            let avatarUrl = cachedProfile.avatarUrl
            if avatarUrl != "TBD" && !avatarUrl.isEmpty {
                if let cachedImage = CacheManager.shared.loadImage(for: avatarUrl) {
                    self.authorAvatarImage = cachedImage
                    return
                }
            }
        }
        
        Task {
            do {
                let profile = try await APIService.shared.getProfile(suiAddress: comment.author)
                
                await MainActor.run {
                    self.authorProfile = profile
                    CacheManager.shared.saveProfile(profile, for: comment.author)
                }
                
                // 加载头像
                let avatarUrl = profile.avatarUrl
                if avatarUrl != "TBD" && !avatarUrl.isEmpty,
                   let url = URL(string: avatarUrl) {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let image = UIImage(data: data) {
                        await MainActor.run {
                            self.authorAvatarImage = image
                            CacheManager.shared.saveImage(image, for: avatarUrl)
                        }
                    }
                }
            } catch {
                print("⚠️ 获取评论作者信息失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func timeAgoString(from dateString: String) -> String {
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
