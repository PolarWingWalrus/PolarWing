//
//  PhotoSignatureService.swift
//  Polarwing
//
//  Created on 2025-11-24.
//  照片签名服务：对照片hash进行签名并写入metadata
//

import Foundation
import UIKit
import ImageIO
import CryptoKit

class PhotoSignatureService {
    static let shared = PhotoSignatureService()
    
    private init() {}
    
    // MARK: - 签名照片
    
    /// 对照片进行签名并将签名数据写入metadata
    /// - Parameters:
    ///   - image: 原始照片
    ///   - completion: 完成回调，返回包含签名metadata的照片数据
    func signPhoto(_ image: UIImage, completion: @escaping (Result<SignedPhotoResult, Error>) -> Void) {
        guard let privateKey = P256Signer.shared.privateKey else {
            completion(.failure(PhotoSignatureError.noPrivateKey))
            return
        }
        
        guard let publicKey = P256Signer.shared.publicKey else {
            completion(.failure(PhotoSignatureError.noPublicKey))
            return
        }
        
        // 1. 将照片转换为数据
        guard let imageData = image.jpegData(compressionQuality: 0.95) else {
            completion(.failure(PhotoSignatureError.imageConversionFailed))
            return
        }
        
        // 2. 计算照片的 BLAKE2b hash
        let photoHash = Blake2b.hash(data: imageData, outputLength: 32)
        
        print("📸 照片信息:")
        print("  - 大小: \(imageData.count) bytes")
        print("  - Hash (BLAKE2b): \(photoHash.map { String(format: "%02x", $0) }.joined())")
        
        // 3. 对 hash 进行签名
        do {
            let signature = try privateKey.signature(for: photoHash)
            let derSignature = signature.derRepresentation
            
            print("✍️ 签名信息:")
            print("  - 签名长度: \(derSignature.count) bytes")
            print("  - 签名 (Hex): \(derSignature.map { String(format: "%02x", $0) }.joined())")
            print("  - 签名 (Base64): \(derSignature.base64EncodedString())")
            
            // 4. 生成 Sui 地址
            let suiAddress = P256Signer.shared.generateSuiAddress() ?? ""
            
            // 5. 创建签名metadata
            let metadata = PhotoSignatureMetadata(
                signature: derSignature,
                photoHash: photoHash,
                publicKey: publicKey,
                suiAddress: suiAddress,
                timestamp: Date(),
                signatureAlgorithm: "ECDSA-P256",
                hashAlgorithm: "BLAKE2b-256"
            )
            
            // 6. 将metadata写入照片
            guard let signedImageData = writeMetadataToImage(imageData: imageData, metadata: metadata) else {
                completion(.failure(PhotoSignatureError.metadataWriteFailed))
                return
            }
            
            print("✅ 照片签名成功")
            print("  - Sui 地址: \(suiAddress)")
            print("  - 时间戳: \(metadata.timestamp)")
            
            let result = SignedPhotoResult(
                signedImageData: signedImageData,
                metadata: metadata,
                originalImage: image
            )
            
            completion(.success(result))
            
        } catch {
            print("❌ 签名失败: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }
    
    // MARK: - 写入Metadata
    
    /// 将签名metadata写入照片的EXIF数据
    private func writeMetadataToImage(imageData: Data, metadata: PhotoSignatureMetadata) -> Data? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let uti = CGImageSourceGetType(source) else {
            return nil
        }
        
        let destinationData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(destinationData, uti, 1, nil) else {
            return nil
        }
        
        // 获取原始图片的属性
        var properties: [String: Any] = [:]
        if let imageProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
            properties = imageProperties
        }
        
        // 创建自定义的签名metadata字典
        // 使用 EXIF UserComment 字段存储签名信息
        var exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        
        // 将签名数据编码为JSON
        let signatureInfo: [String: Any] = [
            "signature": metadata.signature.base64EncodedString(),
            "photoHash": metadata.photoHash.base64EncodedString(),
            "publicKey": metadata.publicKey.base64EncodedString(),
            "suiAddress": metadata.suiAddress,
            "timestamp": ISO8601DateFormatter().string(from: metadata.timestamp),
            "signatureAlgorithm": metadata.signatureAlgorithm,
            "hashAlgorithm": metadata.hashAlgorithm,
            "version": "1.0"
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: signatureInfo, options: [.prettyPrinted]),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            // 存储到 UserComment
            exifDict[kCGImagePropertyExifUserComment as String] = jsonString
            properties[kCGImagePropertyExifDictionary as String] = exifDict
            
            // 也可以存储到 ImageDescription
            properties[kCGImagePropertyTIFFDictionary as String] = [
                kCGImagePropertyTIFFImageDescription as String: "Signed by Polarwing - \(metadata.suiAddress)"
            ]
            
            print("📝 Metadata 写入信息:")
            print(jsonString)
        }
        
        // 添加图片到目标
        CGImageDestinationAddImageFromSource(destination, source, 0, properties as CFDictionary)
        
        // 完成写入
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        return destinationData as Data
    }
    
    // MARK: - 读取和验证Metadata
    
    /// 从照片中读取签名metadata
    func readSignatureMetadata(from imageData: Data) -> PhotoSignatureMetadata? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any],
              let userComment = exifDict[kCGImagePropertyExifUserComment as String] as? String,
              let jsonData = userComment.data(using: .utf8),
              let signatureInfo = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }
        
        // 解析签名信息
        guard let signatureBase64 = signatureInfo["signature"] as? String,
              let photoHashBase64 = signatureInfo["photoHash"] as? String,
              let publicKeyBase64 = signatureInfo["publicKey"] as? String,
              let suiAddress = signatureInfo["suiAddress"] as? String,
              let timestampString = signatureInfo["timestamp"] as? String,
              let signatureAlgorithm = signatureInfo["signatureAlgorithm"] as? String,
              let hashAlgorithm = signatureInfo["hashAlgorithm"] as? String,
              let signature = Data(base64Encoded: signatureBase64),
              let photoHash = Data(base64Encoded: photoHashBase64),
              let publicKey = Data(base64Encoded: publicKeyBase64),
              let timestamp = ISO8601DateFormatter().date(from: timestampString) else {
            return nil
        }
        
        return PhotoSignatureMetadata(
            signature: signature,
            photoHash: photoHash,
            publicKey: publicKey,
            suiAddress: suiAddress,
            timestamp: timestamp,
            signatureAlgorithm: signatureAlgorithm,
            hashAlgorithm: hashAlgorithm
        )
    }
    
    /// 验证照片签名
    func verifyPhotoSignature(imageData: Data) -> SignatureVerificationResult {
        // 1. 读取metadata
        guard let metadata = readSignatureMetadata(from: imageData) else {
            return SignatureVerificationResult(
                isValid: false,
                error: "无法读取签名metadata",
                metadata: nil,
                currentHash: nil,
                expectedHash: nil
            )
        }
        
        // 2. 从照片中移除metadata,计算原始照片的hash
        guard let cleanImageData = removeMetadataFromImage(imageData: imageData) else {
            return SignatureVerificationResult(
                isValid: false,
                error: "无法处理照片数据",
                metadata: metadata,
                currentHash: nil,
                expectedHash: metadata.photoHash
            )
        }
        
        let currentHash = Blake2b.hash(data: cleanImageData, outputLength: 32)
        
        // 3. 验证hash是否匹配
        guard currentHash == metadata.photoHash else {
            return SignatureVerificationResult(
                isValid: false,
                error: "照片hash不匹配，照片可能已被篡改",
                metadata: metadata,
                currentHash: currentHash,
                expectedHash: metadata.photoHash
            )
        }
        
        // 4. 验证签名
        do {
            let publicKey = try P256.Signing.PublicKey(x963Representation: metadata.publicKey)
            let signature = try P256.Signing.ECDSASignature(derRepresentation: metadata.signature)
            
            let isValid = publicKey.isValidSignature(signature, for: metadata.photoHash)
            
            if isValid {
                print("✅ 照片签名验证成功")
                print("  - 签名者: \(metadata.suiAddress)")
                print("  - 签名时间: \(metadata.timestamp)")
                print("  - Hash匹配: ✅")
                print("  - 签名有效: ✅")
            } else {
                print("❌ 签名验证失败")
            }
            
            return SignatureVerificationResult(
                isValid: isValid,
                error: isValid ? nil : "签名验证失败",
                metadata: metadata,
                currentHash: currentHash,
                expectedHash: metadata.photoHash
            )
            
        } catch {
            return SignatureVerificationResult(
                isValid: false,
                error: "签名验证错误: \(error.localizedDescription)",
                metadata: metadata,
                currentHash: currentHash,
                expectedHash: metadata.photoHash
            )
        }
    }
    
    /// 移除照片metadata(用于验证时计算原始hash)
    private func removeMetadataFromImage(imageData: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let uti = CGImageSourceGetType(source),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        
        let destinationData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(destinationData, uti, 1, nil) else {
            return nil
        }
        
        // 只添加图片，不添加任何metadata
        CGImageDestinationAddImage(destination, cgImage, nil)
        
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        return destinationData as Data
    }
}

// MARK: - 数据模型

/// 照片签名元数据
struct PhotoSignatureMetadata {
    let signature: Data           // P256 ECDSA签名 (DER格式)
    let photoHash: Data           // 照片的BLAKE2b hash
    let publicKey: Data           // 签名者的公钥
    let suiAddress: String        // 签名者的Sui地址
    let timestamp: Date           // 签名时间戳
    let signatureAlgorithm: String // 签名算法
    let hashAlgorithm: String     // Hash算法
    
    var description: String {
        """
        📝 照片签名信息
        ├─ 签名者: \(suiAddress)
        ├─ 签名时间: \(timestamp)
        ├─ 签名算法: \(signatureAlgorithm)
        ├─ Hash算法: \(hashAlgorithm)
        ├─ 照片Hash: \(photoHash.prefix(16).map { String(format: "%02x", $0) }.joined())...
        └─ 签名: \(signature.prefix(16).map { String(format: "%02x", $0) }.joined())...
        """
    }
}

/// 已签名照片的结果
struct SignedPhotoResult {
    let signedImageData: Data            // 包含签名metadata的照片数据
    let metadata: PhotoSignatureMetadata  // 签名元数据
    let originalImage: UIImage            // 原始照片
    
    /// 保存到文件
    func saveToFile(at url: URL) throws {
        try signedImageData.write(to: url)
    }
    
    /// 转换为UIImage
    func toUIImage() -> UIImage? {
        return UIImage(data: signedImageData)
    }
}

/// 签名验证结果
struct SignatureVerificationResult {
    let isValid: Bool                        // 验证是否通过
    let error: String?                       // 错误信息
    let metadata: PhotoSignatureMetadata?    // 签名元数据
    let currentHash: Data?                   // 当前照片的hash
    let expectedHash: Data?                  // 预期的hash
    
    var description: String {
        if isValid {
            return """
            ✅ 签名验证通过
            \(metadata?.description ?? "")
            """
        } else {
            var result = "❌ 签名验证失败\n"
            if let error = error {
                result += "错误: \(error)\n"
            }
            if let metadata = metadata {
                result += metadata.description
            }
            if let current = currentHash, let expected = expectedHash {
                result += "\n当前Hash: \(current.prefix(8).map { String(format: "%02x", $0) }.joined())..."
                result += "\n预期Hash: \(expected.prefix(8).map { String(format: "%02x", $0) }.joined())..."
            }
            return result
        }
    }
}

/// 照片签名错误
enum PhotoSignatureError: LocalizedError {
    case noPrivateKey
    case noPublicKey
    case imageConversionFailed
    case metadataWriteFailed
    
    var errorDescription: String? {
        switch self {
        case .noPrivateKey:
            return "未找到私钥，请先生成密钥对"
        case .noPublicKey:
            return "未找到公钥"
        case .imageConversionFailed:
            return "照片转换失败"
        case .metadataWriteFailed:
            return "写入metadata失败"
        }
    }
}
