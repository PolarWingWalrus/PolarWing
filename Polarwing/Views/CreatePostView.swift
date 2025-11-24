//
//  CreatePostView.swift
//  Polarwing
//
//  Created on 2025-11-22.
//

import SwiftUI
import PhotosUI
import Photos

struct CreatePostView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var p256Signer = P256Signer.shared
    @State private var selectedImage: UIImage?
    @State private var caption = ""
    @State private var postTitle = ""
    @State private var showCamera = false
    @State private var showPhotoGallery = false
    @State private var isPublishing = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let image = selectedImage {
                    ScrollView {
                        VStack(spacing: 20) {
                            // 显示选中的图片
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 300)
                                .cornerRadius(12)
                            
                            // Title input field
                            TextField("Title", text: $postTitle)
                                .textFieldStyle(.plain)
                                .font(.headline)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            
                            // Caption input field
                            TextField("", text: $caption, axis: .vertical)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                                .lineLimit(3...10)
                        }
                    }
                } else {
                    // 选择图片的选项
                    VStack(spacing: 30) {
                        Spacer()
                        
                        Button(action: {
                            showCamera = true
                        }) {
                            VStack(spacing: 12) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 50))
                                Text("Take Photo")
                                    .font(.headline)
                            }
                            .foregroundColor(Color(red: 172/255, green: 237/255, blue: 228/255))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .background(Color(red: 172/255, green: 237/255, blue: 228/255).opacity(0.1))
                            .cornerRadius(16)
                        }
                        
                        Button(action: {
                            showPhotoGallery = true
                        }) {
                            VStack(spacing: 12) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 50))
                                Text("Choose from Gallery")
                                    .font(.headline)
                            }
                            .foregroundColor(Color(red: 172/255, green: 237/255, blue: 228/255))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .background(Color(red: 172/255, green: 237/255, blue: 228/255).opacity(0.1))
                            .cornerRadius(16)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 30)
                }
            }
            .padding()
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                if selectedImage != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: publishPost) {
                            if isPublishing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("Post")
                                    .fontWeight(.semibold)
                            }
                        }
                        .disabled(isPublishing || postTitle.isEmpty || caption.isEmpty)
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView()
            }
            .fullScreenCover(isPresented: $showPhotoGallery) {
                PhotoGalleryPickerView { image in
                    selectedImage = image
                    showPhotoGallery = false
                }
            }
            .overlay {
                if isPublishing {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Publishing...")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                        .padding(40)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(20)
                    }
                }
            }
            .alert("Publishing Failed", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message {
                Text(errorMessage)
            }
        }
    }
    
    private func publishPost() {
        guard let image = selectedImage,
              let suiAddress = UserDefaults.standard.string(forKey: "suiAddress"),
              let publicKey = p256Signer.publicKey else {
            errorMessage = "缺少必要信息"
            showError = true
            return
        }
        
        isPublishing = true
        
        // 创建签名数据
        let action = "post"
        let timestamp = Int(Date().timeIntervalSince1970)
        let nonce = Int.random(in: 1...Int.max)
        let message = "\(action)\(timestamp)\(nonce)"
        
        print("📝 准备发布帖子")
        print("  - 标题: \(postTitle)")
        print("  - 内容: \(caption)")
        
        // 签名
        p256Signer.signMessage(message) { signResult in
            switch signResult {
            case .success(let signatureResult):
                Task {
                    var imageUrl: String?
                    
                    // ==================== 步骤1: 上传图片 ====================
                    do {
                        print("\n" + String(repeating: "=", count: 50))
                        print("🖼️  步骤1: 开始上传图片到 Walrus")
                        print(String(repeating: "=", count: 50))
                        
                        let uploadResponse = try await APIService.shared.uploadMedia(
                            image: image,
                            storageType: "walrus",
                            suiAddress: suiAddress,
                            publicKey: publicKey.base64EncodedString(),
                            signature: signatureResult.signature.base64EncodedString(),
                            action: action,
                            timestamp: timestamp,
                            nonce: nonce
                        )
                        
                        // 验证是否有 URL
                        if let url = uploadResponse.files.first?.url, !url.isEmpty {
                            imageUrl = url
                            print("\n✅ 步骤1成功: 图片上传完成")
                            print("   📎 图片URL: \(url)")
                            print(String(repeating: "=", count: 50) + "\n")
                        } else {
                            print("\n❌ 步骤1失败: 未获取到图片URL")
                            print(String(repeating: "=", count: 50) + "\n")
                            throw NSError(
                                domain: "CreatePost", 
                                code: 1001, 
                                userInfo: [NSLocalizedDescriptionKey: "步骤1失败: 图片上传后未返回URL地址"]
                            )
                        }
                        
                    } catch {
                        await MainActor.run {
                            isPublishing = false
                            errorMessage = "步骤1失败: 图片上传失败\n\(error.localizedDescription)"
                            showError = true
                            print("\n❌ 步骤1失败 - 终止发帖流程")
                            print("   错误详情: \(error.localizedDescription)")
                            print(String(repeating: "=", count: 50) + "\n")
                        }
                        return
                    }
                    
                    // ==================== 步骤2: 创建帖子 ====================
                    guard let finalImageUrl = imageUrl else {
                        await MainActor.run {
                            isPublishing = false
                            errorMessage = "步骤1失败: 未获取到有效的图片URL"
                            showError = true
                        }
                        return
                    }
                    
                    do {
                        print(String(repeating: "=", count: 50))
                        print("📮 步骤2: 开始创建帖子")
                        print(String(repeating: "=", count: 50))
                        
                        let post = try await APIService.shared.createPost(
                            title: postTitle,
                            content: caption,
                            mediaUrls: [finalImageUrl],
                            tags: ["daily"],
                            visibility: "public",
                            storageType: "walrus",
                            suiAddress: suiAddress,
                            publicKey: publicKey.base64EncodedString(),
                            signature: signatureResult.signature.base64EncodedString(),
                            action: action,
                            timestamp: timestamp,
                            nonce: nonce
                        )
                        
                        // 验证是否有 ID
                        if !post.id.isEmpty {
                            await MainActor.run {
                                print("\n✅ 步骤2成功: 帖子创建完成")
                                print("   🆔 帖子ID: \(post.id)")
                                print("   👤 作者: \(post.author)")
                                print("   🏷️  标签: \(post.tags.joined(separator: ", "))")
                                print(String(repeating: "=", count: 50))
                                print("\n🎉 发布流程完成！\n")
                                
                                isPublishing = false
                                dismiss()
                            }
                        } else {
                            print("\n❌ 步骤2失败: 帖子创建后未返回ID")
                            print(String(repeating: "=", count: 50) + "\n")
                            throw NSError(
                                domain: "CreatePost", 
                                code: 2001, 
                                userInfo: [NSLocalizedDescriptionKey: "步骤2失败: 帖子创建后未返回ID"]
                            )
                        }
                        
                    } catch {
                        await MainActor.run {
                            isPublishing = false
                            errorMessage = "步骤2失败: 帖子创建失败\n\(error.localizedDescription)"
                            showError = true
                            print("\n❌ 步骤2失败 - 发帖流程失败")
                            print("   错误详情: \(error.localizedDescription)")
                            print("   注意: 图片已上传成功，但帖子创建失败")
                            print(String(repeating: "=", count: 50) + "\n")
                        }
                    }
                }
                
            case .failure(let error):
                isPublishing = false
                errorMessage = "签名失败: \(error.localizedDescription)"
                showError = true
                print("\n❌ 签名失败 - 无法开始发帖流程")
                print("   错误详情: \(error.localizedDescription)\n")
            }
        }
    }
}

// MARK: - 带图片的发帖视图
struct CreatePostWithImageView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var p256Signer = P256Signer.shared
    let image: UIImage
    @State private var caption = ""
    @State private var postTitle = ""
    @State private var isPublishing = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 显示选中的图片
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .cornerRadius(12)
                    
                    // 标题输入框
                    TextField("Title", text: $postTitle)
                        .textFieldStyle(.plain)
                        .font(.headline)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    
                    // 内容输入框
                    TextField("", text: $caption, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .lineLimit(3...10)
                }
            }
            .padding()
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: publishPost) {
                        if isPublishing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Post")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isPublishing || postTitle.isEmpty || caption.isEmpty)
                }
            }
            .overlay {
                if isPublishing {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Publishing...")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                        .padding(40)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(20)
                    }
                }
            }
            .alert("Publishing Failed", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func publishPost() {
        guard let suiAddress = UserDefaults.standard.string(forKey: "suiAddress"),
              let publicKey = p256Signer.publicKey else {
            errorMessage = "缺少必要信息"
            showError = true
            return
        }
        
        isPublishing = true
        
        // 创建签名数据
        let action = "post"
        let timestamp = Int(Date().timeIntervalSince1970)
        let nonce = Int.random(in: 1...Int.max)
        let message = "\(action)\(timestamp)\(nonce)"
        
        print("📝 准备发布帖子")
        print("  - 标题: \(postTitle)")
        print("  - 内容: \(caption)")
        
        // 签名
        p256Signer.signMessage(message) { signResult in
            switch signResult {
            case .success(let signatureResult):
                Task {
                    var imageUrl: String?
                    
                    // ==================== 步骤1: 上传图片 ====================
                    do {
                        print("\n" + String(repeating: "=", count: 50))
                        print("🖼️  步骤1: 开始上传图片到 Walrus")
                        print(String(repeating: "=", count: 50))
                        
                        let uploadResponse = try await APIService.shared.uploadMedia(
                            image: image,
                            storageType: "walrus",
                            suiAddress: suiAddress,
                            publicKey: publicKey.base64EncodedString(),
                            signature: signatureResult.signature.base64EncodedString(),
                            action: action,
                            timestamp: timestamp,
                            nonce: nonce
                        )
                        
                        // 验证是否有 URL
                        if let url = uploadResponse.files.first?.url, !url.isEmpty {
                            imageUrl = url
                            print("\n✅ 步骤1成功: 图片上传完成")
                            print("   📎 图片URL: \(url)")
                            print(String(repeating: "=", count: 50) + "\n")
                        } else {
                            print("\n❌ 步骤1失败: 未获取到图片URL")
                            print(String(repeating: "=", count: 50) + "\n")
                            throw NSError(
                                domain: "CreatePost", 
                                code: 1001, 
                                userInfo: [NSLocalizedDescriptionKey: "步骤1失败: 图片上传后未返回URL地址"]
                            )
                        }
                        
                    } catch {
                        await MainActor.run {
                            isPublishing = false
                            errorMessage = "步骤1失败: 图片上传失败\n\(error.localizedDescription)"
                            showError = true
                            print("\n❌ 步骤1失败 - 终止发帖流程")
                            print("   错误详情: \(error.localizedDescription)")
                            print(String(repeating: "=", count: 50) + "\n")
                        }
                        return
                    }
                    
                    // ==================== 步骤2: 创建帖子 ====================
                    guard let finalImageUrl = imageUrl else {
                        await MainActor.run {
                            isPublishing = false
                            errorMessage = "步骤1失败: 未获取到有效的图片URL"
                            showError = true
                        }
                        return
                    }
                    
                    do {
                        print(String(repeating: "=", count: 50))
                        print("📮 步骤2: 开始创建帖子")
                        print(String(repeating: "=", count: 50))
                        
                        let post = try await APIService.shared.createPost(
                            title: postTitle,
                            content: caption,
                            mediaUrls: [finalImageUrl],
                            tags: ["daily"],
                            visibility: "public",
                            storageType: "walrus",
                            suiAddress: suiAddress,
                            publicKey: publicKey.base64EncodedString(),
                            signature: signatureResult.signature.base64EncodedString(),
                            action: action,
                            timestamp: timestamp,
                            nonce: nonce
                        )
                        
                        // 验证是否有 ID
                        if !post.id.isEmpty {
                            await MainActor.run {
                                print("\n✅ 步骤2成功: 帖子创建完成")
                                print("   🆔 帖子ID: \(post.id)")
                                print("   👤 作者: \(post.author)")
                                print("   🏷️  标签: \(post.tags.joined(separator: ", "))")
                                print(String(repeating: "=", count: 50))
                                print("\n🎉 发布流程完成！\n")
                                
                                isPublishing = false
                                dismiss()
                            }
                        } else {
                            print("\n❌ 步骤2失败: 帖子创建后未返回ID")
                            print(String(repeating: "=", count: 50) + "\n")
                            throw NSError(
                                domain: "CreatePost", 
                                code: 2001, 
                                userInfo: [NSLocalizedDescriptionKey: "步骤2失败: 帖子创建后未返回ID"]
                            )
                        }
                        
                    } catch {
                        await MainActor.run {
                            isPublishing = false
                            errorMessage = "步骤2失败: 帖子创建失败\n\(error.localizedDescription)"
                            showError = true
                            print("\n❌ 步骤2失败 - 发帖流程失败")
                            print("   错误详情: \(error.localizedDescription)")
                            print("   注意: 图片已上传成功，但帖子创建失败")
                            print(String(repeating: "=", count: 50) + "\n")
                        }
                    }
                }
                
            case .failure(let error):
                isPublishing = false
                errorMessage = "签名失败: \(error.localizedDescription)"
                showError = true
                print("\n❌ 签名失败 - 无法开始发帖流程")
                print("   错误详情: \(error.localizedDescription)\n")
            }
        }
    }
}

// MARK: - 照片选择器（仅显示 Polarwing 相册）
struct PhotoGalleryPickerView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = PhotoGalleryViewModel()
    let onSelect: (UIImage) -> Void
    
    let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.photoAssets.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("No Photos")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Please take photos using the camera first")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(viewModel.photoAssets, id: \.localIdentifier) { asset in
                                GeometryReader { geometry in
                                    PickerThumbnailView(asset: asset) { image in
                                        onSelect(image)
                                    }
                                    .frame(width: geometry.size.width, height: geometry.size.width)
                                }
                                .aspectRatio(1, contentMode: .fit)
                                .clipped()
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Select Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(Color(red: 172/255, green: 237/255, blue: 228/255))
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadPhotos()
        }
    }
}

// MARK: - 选择器缩略图
struct PickerThumbnailView: View {
    let asset: PHAsset
    let onSelect: (UIImage) -> Void
    @State private var thumbnail: UIImage?
    
    var body: some View {
        Button(action: {
            loadFullImage()
        }) {
            Group {
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            ProgressView()
                                .tint(Color(red: 172/255, green: 237/255, blue: 228/255))
                        )
                }
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = false
        options.isSynchronous = false
        
        let targetSize = CGSize(width: 200, height: 200)
        
        imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            self.thumbnail = image
        }
    }
    
    private func loadFullImage() {
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        let screenScale = UIScreen.main.scale
        let screenSize = UIScreen.main.bounds.size
        let targetSize = CGSize(
            width: screenSize.width * screenScale,
            height: screenSize.height * screenScale
        )
        
        imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            if let image = image {
                onSelect(image)
            }
        }
    }
}
