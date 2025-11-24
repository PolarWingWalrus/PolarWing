# 照片签名功能说明

## 概述

Polarwing 实现了对照片进行数字签名的功能,确保照片的真实性和完整性。每张通过 Polarwing 相机拍摄的照片都会被自动签名,并将签名数据写入照片的 EXIF metadata 中。

## 技术实现

### 1. 签名流程

```
拍摄照片 → 计算Hash → 签名Hash → 写入Metadata → 保存到相册
```

1. **拍摄照片**: 用户通过 Polarwing 相机拍摄照片
2. **计算 Hash**: 使用 BLAKE2b-256 算法计算照片的 hash 值
3. **签名**: 使用用户的 P256 私钥对 hash 进行 ECDSA 签名
4. **写入 Metadata**: 将签名数据写入照片的 EXIF UserComment 字段
5. **保存**: 将签名后的照片保存到 "Polarwing" 相册

### 2. 签名数据结构

照片的 EXIF metadata 中包含以下签名信息:

```json
{
  "signature": "Base64编码的ECDSA签名(DER格式)",
  "photoHash": "Base64编码的照片BLAKE2b hash",
  "publicKey": "Base64编码的签名者公钥",
  "suiAddress": "签名者的Sui地址",
  "timestamp": "ISO8601格式的签名时间",
  "signatureAlgorithm": "ECDSA-P256",
  "hashAlgorithm": "BLAKE2b-256",
  "version": "1.0"
}
```

### 3. 验证流程

```
读取照片 → 提取Metadata → 计算当前Hash → 验证Hash匹配 → 验证签名
```

1. **读取照片**: 从相册或其他来源读取照片
2. **提取 Metadata**: 从 EXIF 中读取签名信息
3. **计算当前 Hash**: 对照片原始数据计算 BLAKE2b hash
4. **验证 Hash**: 比对当前 hash 与签名中的 hash
5. **验证签名**: 使用公钥验证签名的有效性

## 核心组件

### PhotoSignatureService

照片签名服务的核心类,提供以下功能:

#### 主要方法

```swift
// 对照片进行签名
func signPhoto(_ image: UIImage, completion: @escaping (Result<SignedPhotoResult, Error>) -> Void)

// 从照片中读取签名metadata
func readSignatureMetadata(from imageData: Data) -> PhotoSignatureMetadata?

// 验证照片签名
func verifyPhotoSignature(imageData: Data) -> SignatureVerificationResult
```

### 数据模型

#### PhotoSignatureMetadata
存储照片签名的元数据

```swift
struct PhotoSignatureMetadata {
    let signature: Data           // P256 ECDSA签名
    let photoHash: Data           // 照片的BLAKE2b hash
    let publicKey: Data           // 签名者的公钥
    let suiAddress: String        // 签名者的Sui地址
    let timestamp: Date           // 签名时间戳
    let signatureAlgorithm: String // 签名算法
    let hashAlgorithm: String     // Hash算法
}
```

#### SignedPhotoResult
签名操作的结果

```swift
struct SignedPhotoResult {
    let signedImageData: Data            // 包含签名metadata的照片数据
    let metadata: PhotoSignatureMetadata  // 签名元数据
    let originalImage: UIImage            // 原始照片
}
```

#### SignatureVerificationResult
验证操作的结果

```swift
struct SignatureVerificationResult {
    let isValid: Bool                        // 验证是否通过
    let error: String?                       // 错误信息
    let metadata: PhotoSignatureMetadata?    // 签名元数据
    let currentHash: Data?                   // 当前照片的hash
    let expectedHash: Data?                  // 预期的hash
}
```

## 使用场景

### 1. 自动签名(在相机中)

拍照时自动进行签名:

```swift
// 在 CameraManager 中自动调用
PhotoSignatureService.shared.signPhoto(image) { result in
    switch result {
    case .success(let signedResult):
        // 保存签名后的照片
        print(signedResult.metadata.description)
        
    case .failure(let error):
        // 处理签名失败
        print("签名失败: \(error)")
    }
}
```

### 2. 验证照片签名

验证从相册或其他来源获取的照片:

```swift
// 验证照片
let result = PhotoSignatureService.shared.verifyPhotoSignature(imageData: photoData)

if result.isValid {
    print("✅ 签名有效")
    print("签名者: \(result.metadata?.suiAddress ?? "")")
} else {
    print("❌ 签名无效: \(result.error ?? "")")
}
```

### 3. 读取签名信息

仅读取照片的签名信息而不验证:

```swift
if let metadata = PhotoSignatureService.shared.readSignatureMetadata(from: imageData) {
    print("签名者: \(metadata.suiAddress)")
    print("签名时间: \(metadata.timestamp)")
    print("算法: \(metadata.signatureAlgorithm)")
}
```

## 测试工具

项目包含 `PhotoSignatureTestView`,可用于测试照片签名功能:

1. 检查密钥状态
2. 从相册选择照片
3. 自动验证照片签名
4. 显示详细的验证结果

## 安全特性

### 1. 加密算法
- **签名算法**: ECDSA with P-256 (secp256r1)
- **Hash算法**: BLAKE2b-256
- **密钥格式**: X9.63 (公钥), Raw Representation (私钥)
- **签名格式**: DER encoding

### 2. 防篡改
- 任何对照片内容的修改都会导致 hash 不匹配
- 签名验证失败表示照片已被篡改或签名无效

### 3. 隐私保护
- 私钥安全存储在设备的 Keychain 中
- 只有公钥和 Sui 地址会写入照片 metadata
- 私钥永远不会离开设备

## 与 Sui 区块链集成

### Sui 地址生成

签名者的 Sui 地址通过以下方式生成:

```swift
// Sui 地址 = BLAKE2b(flag || public_key)
// flag = 0x02 表示 secp256r1 (P256)
let signatureSchemeFlag: UInt8 = 0x02
var dataToHash = Data([signatureSchemeFlag])
dataToHash.append(publicKeyData)
let hash = Blake2b.hash(data: dataToHash, outputLength: 32)
let suiAddress = "0x" + hash.map { String(format: "%02x", $0) }.joined()
```

### 链上验证

照片签名可以在 Sui 区块链上进行验证:

1. 从照片 metadata 中提取签名数据
2. 使用 Sui Move 的 `ecdsa_k1::secp256r1_verify` 函数验证签名
3. 验证签名者的 Sui 地址

## 注意事项

1. **密钥管理**: 首次使用前需要生成密钥对
2. **权限要求**: 需要相册读写权限
3. **照片格式**: 支持 JPEG 格式(最常用)
4. **Metadata兼容性**: 某些照片编辑应用可能会移除 EXIF 数据
5. **性能考虑**: 签名过程在后台线程执行,不会阻塞 UI

## 未来改进

1. 支持批量签名和验证
2. 云端备份密钥对(加密存储)
3. 多设备同步密钥
4. 链上注册照片 hash
5. 时间戳服务集成
6. 照片溯源功能
