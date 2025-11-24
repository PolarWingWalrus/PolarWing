//
//  OnboardingView.swift
//  Polarwing
//
//  Created on 2025-11-22.
//

import SwiftUI

struct OnboardingView: View {
    @StateObject private var p256Signer = P256Signer.shared
    @Binding var isOnboardingComplete: Bool
    
    // Mint green theme color
    private let themeColor = Color(red: 172/255, green: 237/255, blue: 228/255)
    
    // 用户类型选择
    @State private var userType: UserType? = nil
    
    // 新用户设置
    @State private var username = ""
    @State private var selectedAvatar: UIImage?
    @State private var showImagePicker = false
    
    // 老用户导入
    @State private var privateKeyInput = ""
    
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    enum UserType {
        case newUser
        case existingUser
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if userType == nil {
                // 用户类型选择界面
                userTypeSelectionView
            } else if userType == .newUser {
                // 新用户设置界面
                newUserSetupView
            } else if userType == .existingUser {
                // 老用户导入界面
                existingUserImportView
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedAvatar)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - 用户类型选择界面
    
    private var userTypeSelectionView: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundColor(themeColor)
                
                Text("Welcome to Polarwing")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Choose how you'd like to get started")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            VStack(spacing: 16) {
                // 新用户按钮
                Button(action: {
                    withAnimation {
                        userType = .newUser
                    }
                }) {
                    VStack(spacing: 12) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 40))
                        
                        Text("I'm New Here")
                            .font(.headline)
                        
                        Text("Create a new account")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(themeColor, lineWidth: 2)
                    )
                }
                .foregroundColor(.white)
                
                // 老用户按钮
                Button(action: {
                    withAnimation {
                        userType = .existingUser
                    }
                }) {
                    VStack(spacing: 12) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 40))
                        
                        Text("I Have an Account")
                            .font(.headline)
                        
                        Text("Import your private key")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(themeColor, lineWidth: 2)
                    )
                }
                .foregroundColor(.white)
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
    }
    
    // MARK: - 新用户设置界面
    
    private var newUserSetupView: some View {
        VStack(spacing: 40) {
            // 返回按钮
            HStack {
                Button(action: {
                    withAnimation {
                        userType = nil
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(themeColor)
                }
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.top, 20)
            
            Spacer()
            
            VStack(spacing: 16) {
                // 头像选择
                Button(action: { showImagePicker = true }) {
                    if let avatar = selectedAvatar {
                        Image(uiImage: avatar)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(themeColor, lineWidth: 3)
                            )
                    } else {
                        Image(systemName: "camera.circle.fill")
                            .resizable()
                            .frame(width: 100, height: 100)
                            .foregroundColor(themeColor)
                    }
                }
                
                Text(selectedAvatar == nil ? "Tap to upload avatar" : "Tap to change avatar")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text("Set Your Username")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Choose a unique username for your account")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            VStack(spacing: 20) {
                TextField("Enter username", text: $username)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Button(action: setupNewUserAccount) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Create Account")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(username.isEmpty ? Color.gray : themeColor)
                    .cornerRadius(16)
                }
                .disabled(username.isEmpty || isProcessing)
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
    }
    
    // MARK: - 老用户导入界面
    
    private var existingUserImportView: some View {
        VStack(spacing: 30) {
            // 返回按钮
            HStack {
                Button(action: {
                    withAnimation {
                        userType = nil
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(themeColor)
                }
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.top, 20)
            
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "key.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(themeColor)
                
                Text("Import Your Account")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Enter your private key to restore your account")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Private Key (Base64)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    TextEditor(text: $privateKeyInput)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .frame(height: 150)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Security Notice")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    Text("• Keep your private key secure\n• Never share it with anyone\n• Make sure you trust this device")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                
                Button(action: importExistingUserAccount) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Import Account")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(privateKeyInput.isEmpty ? Color.gray : themeColor)
                    .cornerRadius(16)
                }
                .disabled(privateKeyInput.isEmpty || isProcessing)
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
    }
    
    // MARK: - 新用户账户设置
    
    private func setupNewUserAccount() {
        isProcessing = true
        
        // 生成 P256 密钥对
        p256Signer.generateKeyPair { result in
            switch result {
            case .success(let publicKey):
                print("🔑 成功生成密钥对")
                print("  - 公钥 (Base64): \(publicKey.base64EncodedString())")
                print("  - 公钥长度: \(publicKey.count) 字节")
                
                // 创建需要签名的消息
                let action = "upload"
                let timestamp = Int(Date().timeIntervalSince1970)
                let nonce = Int.random(in: 1...Int.max)
                let message = "\(action)\(timestamp)\(nonce)"
                
                print("📝 构建签名消息")
                print("  - action: \(action)")
                print("  - timestamp: \(timestamp)")
                print("  - nonce: \(nonce)")
                print("  - 完整消息: \(message)")
                
                // 获取 Sui 地址
                guard let suiAddress = p256Signer.generateSuiAddress() else {
                    isProcessing = false
                    errorMessage = "生成地址失败"
                    showError = true
                    return
                }
                
                print("🏠 生成 Sui 地址: \(suiAddress)")
                
                // 签名
                p256Signer.signMessage(message) { signResult in
                    switch signResult {
                    case .success(let signatureResult):
                        print("✍️ 签名成功")
                        print("  - 签名 (Base64): \(signatureResult.signature.base64EncodedString())")
                        print("  - 签名长度: \(signatureResult.signature.count) 字节")
                        
                        // 调用 API
                        Task {
                            do {
                                var avatarUrl = "TBD"
                                
                                // 如果用户选择了头像，先上传头像
                                if let avatar = selectedAvatar {
                                    print("🖼️ 开始上传头像...")
                                    
                                    let uploadResponse = try await APIService.shared.uploadMedia(
                                        image: avatar,
                                        storageType: "walrus",
                                        suiAddress: suiAddress,
                                        publicKey: publicKey.base64EncodedString(),
                                        signature: signatureResult.signature.base64EncodedString(),
                                        action: action,
                                        timestamp: timestamp,
                                        nonce: nonce
                                    )
                                    
                                    if let uploadedFile = uploadResponse.files.first {
                                        avatarUrl = uploadedFile.url
                                        print("✅ 头像上传成功: \(avatarUrl)")
                                    }
                                }
                                
                                print("\n📋 准备发送的完整数据:")
                                print("  - nickname: \(username)")
                                print("  - avatarUrl: \(avatarUrl)")
                                print("  - bio: TBD")
                                print("  - suiAddress: \(suiAddress)")
                                print("  - publicKey: \(publicKey.base64EncodedString())")
                                print("  - signature: \(signatureResult.signature.base64EncodedString())")
                                print("  - action: \(action)")
                                print("  - timestamp: \(timestamp)")
                                print("  - nonce: \(nonce)")
                                
                                let profile = try await APIService.shared.updateProfile(
                                    nickname: username,
                                    avatarUrl: avatarUrl,
                                    bio: "TBD",
                                    suiAddress: suiAddress,
                                    publicKey: publicKey.base64EncodedString(),
                                    signature: signatureResult.signature.base64EncodedString(),
                                    action: action,
                                    timestamp: timestamp,
                                    nonce: nonce
                                )
                                
                                // 保存用户名和地址
                                await MainActor.run {
                                    UserDefaults.standard.set(username, forKey: "username")
                                    UserDefaults.standard.set(suiAddress, forKey: "suiAddress")
                                    print("✅ 账户设置成功")
                                    print("  - 昵称: \(profile.nickname)")
                                    print("  - 地址: \(profile.address)")
                                    isProcessing = false
                                    isOnboardingComplete = true
                                }
                            } catch {
                                await MainActor.run {
                                    isProcessing = false
                                    errorMessage = "注册失败: \(error.localizedDescription)"
                                    showError = true
                                }
                            }
                        }
                        
                    case .failure(let error):
                        isProcessing = false
                        errorMessage = "签名失败: \(error.localizedDescription)"
                        showError = true
                    }
                }
                
            case .failure(let error):
                isProcessing = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    // MARK: - 老用户账户导入
    
    private func importExistingUserAccount() {
        isProcessing = true
        
        // 导入私钥
        p256Signer.importPrivateKey(privateKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)) { result in
            switch result {
            case .success(let publicKey):
                print("🔑 成功导入私钥")
                print("  - 公钥 (Base64): \(publicKey.base64EncodedString())")
                
                // 获取 Sui 地址
                guard let suiAddress = p256Signer.generateSuiAddress() else {
                    isProcessing = false
                    errorMessage = "生成地址失败"
                    showError = true
                    return
                }
                
                print("🏠 恢复 Sui 地址: \(suiAddress)")
                
                // 获取用户信息
                Task {
                    do {
                        let profile = try await APIService.shared.getProfile(suiAddress: suiAddress)
                        
                        // 保存用户信息
                        await MainActor.run {
                            UserDefaults.standard.set(profile.nickname, forKey: "username")
                            UserDefaults.standard.set(suiAddress, forKey: "suiAddress")
                            
                            print("✅ 账户恢复成功")
                            print("  - 昵称: \(profile.nickname)")
                            print("  - 地址: \(profile.address)")
                            
                            isProcessing = false
                            isOnboardingComplete = true
                        }
                    } catch {
                        await MainActor.run {
                            isProcessing = false
                            errorMessage = "获取用户信息失败: \(error.localizedDescription)\n\n请确认私钥正确且该账户已注册"
                            showError = true
                        }
                    }
                }
                
            case .failure(let error):
                isProcessing = false
                errorMessage = "导入失败: \(error.localizedDescription)\n\n请检查私钥格式是否正确"
                showError = true
            }
        }
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.image = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.image = originalImage
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
