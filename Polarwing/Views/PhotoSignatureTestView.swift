//
//  PhotoSignatureTestView.swift
//  Polarwing
//
//  Created on 2025-11-24.
//  照片签名功能测试界面
//

import SwiftUI
import PhotosUI

struct PhotoSignatureTestView: View {
    @StateObject private var signer = P256Signer.shared
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var verificationResult: SignatureVerificationResult?
    @State private var isProcessing = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 密钥状态
                    keyStatusSection
                    
                    // 选择照片
                    photoPickerSection
                    
                    // 照片预览
                    if let image = selectedImage {
                        imagePreviewSection(image: image)
                    }
                    
                    // 验证结果
                    if let result = verificationResult {
                        verificationResultSection(result: result)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("照片签名测试")
            .navigationBarTitleDisplayMode(.inline)
            .alert("提示", isPresented: $showAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - 密钥状态部分
    
    private var keyStatusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("密钥状态")
                .font(.headline)
            
            HStack {
                Image(systemName: signer.isAuthenticated ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(signer.isAuthenticated ? .green : .red)
                
                Text(signer.isAuthenticated ? "已生成密钥对" : "未生成密钥对")
                
                Spacer()
                
                if !signer.isAuthenticated {
                    Button("生成密钥") {
                        signer.generateKeyPair { result in
                            switch result {
                            case .success:
                                alertMessage = "密钥对生成成功"
                                showAlert = true
                            case .failure(let error):
                                alertMessage = "密钥对生成失败: \(error.localizedDescription)"
                                showAlert = true
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            if let suiAddress = signer.generateSuiAddress() {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Sui 地址:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(suiAddress)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.blue)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    // MARK: - 照片选择部分
    
    private var photoPickerSection: some View {
        VStack(spacing: 10) {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                    Text("选择照片进行验证")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(red: 172/255, green: 237/255, blue: 228/255))
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .onChange(of: selectedItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                        verifyPhoto(imageData: data)
                    }
                }
            }
            
            Text("请选择从 Polarwing 相机拍摄的照片")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - 照片预览部分
    
    private func imagePreviewSection(image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("照片预览")
                .font(.headline)
            
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
                .cornerRadius(10)
            
            HStack {
                Text("尺寸:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(Int(image.size.width)) × \(Int(image.size.height))")
                    .font(.caption)
                
                Spacer()
                
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    // MARK: - 验证结果部分
    
    private func verificationResultSection(result: SignatureVerificationResult) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: result.isValid ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .font(.title2)
                    .foregroundColor(result.isValid ? .green : .red)
                
                Text(result.isValid ? "签名验证通过" : "签名验证失败")
                    .font(.headline)
                    .foregroundColor(result.isValid ? .green : .red)
            }
            
            if let metadata = result.metadata {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    infoRow(label: "签名者", value: metadata.suiAddress)
                    infoRow(label: "签名时间", value: formatDate(metadata.timestamp))
                    infoRow(label: "签名算法", value: metadata.signatureAlgorithm)
                    infoRow(label: "Hash算法", value: metadata.hashAlgorithm)
                    
                    if let photoHash = result.expectedHash {
                        infoRow(label: "照片Hash", value: photoHash.prefix(8).map { String(format: "%02x", $0) }.joined() + "...")
                    }
                    
                    if let currentHash = result.currentHash,
                       let expectedHash = result.expectedHash,
                       currentHash != expectedHash {
                        Divider()
                        Text("⚠️ Hash不匹配，照片可能已被篡改")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            if let error = result.error {
                Divider()
                Text("错误信息: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(result.isValid ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(result.isValid ? Color.green : Color.red, lineWidth: 2)
        )
    }
    
    // MARK: - 辅助视图
    
    private func infoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    // MARK: - 验证照片
    
    private func verifyPhoto(imageData: Data) {
        isProcessing = true
        verificationResult = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result = PhotoSignatureService.shared.verifyPhotoSignature(imageData: imageData)
            
            DispatchQueue.main.async {
                self.verificationResult = result
                self.isProcessing = false
                
                print(result.description)
            }
        }
    }
}

#Preview {
    PhotoSignatureTestView()
}
