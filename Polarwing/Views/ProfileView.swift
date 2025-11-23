//
//  ProfileView.swift
//  Polarwing
//
//  Created on 2025-11-22.
//

import SwiftUI

struct ProfileView: View {
    @StateObject private var passkeyManager = PasskeyManager.shared
    @State private var tapCount = 0
    @State private var showPasskeyInfo = false
    
    // 模拟当前用户的帖子（实际应该从数据源筛选）
    let currentUserId = "user1"
    
    var username: String {
        UserDefaults.standard.string(forKey: "username") ?? "用户"
    }
    
    var userPosts: [Post] {
        MockData.posts.filter { $0.userId == currentUserId }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 用户信息头部
                VStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.blue)
                        .onTapGesture {
                            tapCount += 1
                            if tapCount >= 3 {
                                showPasskeyInfo = true
                                tapCount = 0
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                tapCount = 0
                            }
                        }
                    
                    Text(username)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 30) {
                        VStack(spacing: 4) {
                            Text("\(userPosts.count)")
                                .font(.headline)
                                .fontWeight(.bold)
                            Text("帖子")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        VStack(spacing: 4) {
                            Text("\(userPosts.reduce(0) { $0 + $1.likes })")
                                .font(.headline)
                                .fontWeight(.bold)
                            Text("获赞")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.vertical, 20)
                
                Divider()
                
                // 用户的帖子网格
                if userPosts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("还没有发布帖子")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    PostGridView(posts: userPosts, showUsername: false)
                }
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPasskeyInfo) {
                PasskeyDebugView()
            }
        }
    }
}

struct PasskeyDebugView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var passkeyManager = PasskeyManager.shared
    @State private var copiedItem = ""
    @State private var passkeyID = "未设置"
    @State private var attestationObject = "未设置"
    @State private var publicKey = "未设置"
    @State private var publicKeyHex = "未设置"
    @State private var testMessage = "Hello Sui Blockchain!"
    @State private var lastSignature = "未生成"
    @State private var verificationResult = ""
    @State private var isSigning = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Passkey ID
                    DebugInfoSection(
                        title: "Passkey ID",
                        content: passkeyID,
                        copiedItem: $copiedItem
                    )
                    
                    // Attestation Object
                    DebugInfoSection(
                        title: "Attestation Object",
                        content: attestationObject,
                        copiedItem: $copiedItem
                    )
                    
                    // Public Key (Base64)
                    DebugInfoSection(
                        title: "P256 公钥 (Base64)",
                        content: publicKey,
                        copiedItem: $copiedItem
                    )
                    
                    // Public Key (Hex)
                    DebugInfoSection(
                        title: "P256 公钥 (Hex)",
                        content: publicKeyHex,
                        copiedItem: $copiedItem
                    )
                    
                    Divider()
                        .padding(.vertical)
                    
                    // 签名测试部分
                    VStack(alignment: .leading, spacing: 12) {
                        Text("签名测试")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("测试消息")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            TextField("输入要签名的消息", text: $testMessage)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        Button(action: signTestMessage) {
                            HStack {
                                if isSigning {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "signature")
                                    Text("生成签名")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isSigning || testMessage.isEmpty)
                        
                        if lastSignature != "未生成" {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("签名结果 (Base64)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                Text(lastSignature)
                                    .font(.system(.caption, design: .monospaced))
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                    .textSelection(.enabled)
                            }
                        }
                        
                        if !verificationResult.isEmpty {
                            HStack {
                                Image(systemName: verificationResult.contains("✅") ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(verificationResult.contains("✅") ? .green : .red)
                                Text(verificationResult)
                                    .font(.subheadline)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(verificationResult.contains("✅") ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    
                    Divider()
                        .padding(.vertical)
                    
                    // 重新创建 Passkey 按钮
                    Button(action: recreatePasskey) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("重新创建 Passkey")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
            .navigationTitle("Passkey 调试")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadPasskeyData()
            }
        }
    }
    
    private func loadPasskeyData() {
        // 加载 Passkey ID
        if let id = passkeyManager.currentCredentialID {
            passkeyID = id
        } else if let savedID = passkeyManager.getSavedCredentialID() {
            passkeyID = savedID.base64EncodedString()
        }
        
        // 加载 Attestation Object
        if let attestation = passkeyManager.attestationObject {
            attestationObject = attestation.base64EncodedString()
        } else if let savedAttestation = passkeyManager.getSavedAttestationObject() {
            attestationObject = savedAttestation.base64EncodedString()
        }
        
        // 加载 Public Key
        if let pk = passkeyManager.publicKey {
            publicKey = pk.base64EncodedString()
            publicKeyHex = pk.map { String(format: "%02x", $0) }.joined()
        } else if let savedPK = passkeyManager.getSavedPublicKey() {
            publicKey = savedPK.base64EncodedString()
            publicKeyHex = savedPK.map { String(format: "%02x", $0) }.joined()
        }
        
        // 打印调试信息
        print("📱 Passkey 调试信息:")
        print("  - Passkey ID: \(passkeyID)")
        print("  - Attestation Object: \(attestationObject.prefix(50))...")
        print("  - Public Key: \(publicKey)")
        print("  - Public Key (Hex): \(publicKeyHex)")
    }
    
    private func recreatePasskey() {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first else {
            return
        }
        
        passkeyManager.createPasskey(anchor: window) { result in
            switch result {
            case .success(let credentialID):
                print("✅ Passkey 重新创建成功: \(credentialID.base64EncodedString())")
                // 重新加载数据
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    loadPasskeyData()
                }
            case .failure(let error):
                print("❌ Passkey 创建失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func signTestMessage() {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first else {
            return
        }
        
        isSigning = true
        verificationResult = ""
        
        passkeyManager.signMessage(testMessage, anchor: window) { result in
            isSigning = false
            
            switch result {
            case .success(let signatureResult):
                lastSignature = signatureResult.signature.base64EncodedString()
                
                print("✅ 签名成功")
                print("  - Message: \(testMessage)")
                print("  - Signature: \(lastSignature)")
                
                // 立即验证签名
                if let publicKeyData = passkeyManager.publicKey ?? passkeyManager.getSavedPublicKey() {
                    let isValid = passkeyManager.verifySignature(
                        signature: signatureResult.signature,
                        authenticatorData: signatureResult.authenticatorData,
                        clientDataJSON: signatureResult.clientDataJSON,
                        publicKey: publicKeyData
                    )
                    
                    verificationResult = isValid ? "✅ 签名验证成功！" : "❌ 签名验证失败"
                } else {
                    verificationResult = "❌ 无法获取公钥"
                }
                
            case .failure(let error):
                print("❌ 签名失败: \(error.localizedDescription)")
                verificationResult = "❌ 签名失败: \(error.localizedDescription)"
            }
        }
    }
}

struct DebugInfoSection: View {
    let title: String
    let content: String
    @Binding var copiedItem: String
    
    var isCopied: Bool {
        copiedItem == title
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            Text(content)
                .font(.system(.caption, design: .monospaced))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .textSelection(.enabled)
            
            Button(action: {
                UIPasteboard.general.string = content
                copiedItem = title
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if copiedItem == title {
                        copiedItem = ""
                    }
                }
            }) {
                HStack {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    Text(isCopied ? "已复制" : "复制")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isCopied ? Color.green : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
    }
}
