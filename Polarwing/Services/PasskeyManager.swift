//
//  PasskeyManager.swift
//  Polarwing
//
//  Created on 2025-11-22.
//

import Foundation
import AuthenticationServices
import CryptoKit

class PasskeyManager: NSObject, ObservableObject {
    static let shared = PasskeyManager()
    
    @Published var isAuthenticated = false
    @Published var currentCredentialID: String?
    @Published var attestationObject: Data?
    @Published var publicKey: Data?
    @Published var lastSignature: Data?
    @Published var lastAuthenticatorData: Data?
    @Published var lastClientDataJSON: Data?
    
    // NOTE: Passkey (WebAuthn) requires a valid Associated Domains configuration.
    // The RP ID (relyingPartyIdentifier) must match an HTTPS domain whose
    // AASA file (`/.well-known/apple-app-site-association`) is reachable,
    // returns 200 with `application/json`, and contains this app’s AppID
    // (TEAM_ID.BUNDLE_ID) under `webcredentials.apps`.
    //
    // If the domain/AASA file changes, iOS may still use a cached association
    // from a previous build. This leads to errors such as:
    // “Unable to verify webcredentials association” or AuthorizationError 1004.
    //
    // FIX:
    // 1. Update the AASA file (no redirects, correct JSON).
    // 2. Ensure `webcredentials:<domain>` exists in the app entitlements.
    // 3. **Delete the app from the device** so iOS refreshes the domain association.
    // 4. **Clean the Xcode build folder** and rebuild before reinstalling.
    //
    // Without reinstalling the app, the device may continue using stale
    // associated-domain metadata and fail passkey registration.
    private let rpID = "api2-polarwing.ngrok.app"
    private let userID = "new user"
    
    private override init() {
        super.init()
    }
    
    // 创建新的Passkey
    func createPasskey(anchor: ASPresentationAnchor, completion: @escaping (Result<Data, Error>) -> Void) {
        let challenge = generateChallenge()
        let userIDData = userID.data(using: .utf8)!
        
        let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpID)
        
        let registrationRequest = platformProvider.createCredentialRegistrationRequest(
            challenge: challenge,
            name: userID,
            userID: userIDData
        )
        
        let authController = ASAuthorizationController(authorizationRequests: [registrationRequest])
        authController.delegate = self
        authController.presentationContextProvider = self
        authController.performRequests()
        
        self.registrationCompletion = completion
    }
    
    // 使用已有的Passkey进行认证
    func authenticateWithPasskey(anchor: ASPresentationAnchor, completion: @escaping (Result<Data, Error>) -> Void) {
        let challenge = generateChallenge()
        
        let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpID)
        
        let assertionRequest = platformProvider.createCredentialAssertionRequest(challenge: challenge)
        
        let authController = ASAuthorizationController(authorizationRequests: [assertionRequest])
        authController.delegate = self
        authController.presentationContextProvider = self
        authController.performRequests()
        
        self.authenticationCompletion = completion
    }
    
    // 使用 Passkey 对消息进行签名
    // WebAuthn Signature (Assertion: webauthn.get)
    // The authenticator generates a signature over:
    //     signedData = authenticatorData || SHA256(clientDataJSON)
    // authenticatorData (binary):
    // - rpIdHash (32 bytes): SHA-256 of the RP ID (domain)
    // - flags (1 byte): UP (user present), UV (user verified), etc.
    // - signCount (4 bytes): signature counter
    // - No attestedCredentialData in assertions (only in registration)
    // clientDataJSON (UTF-8 JSON):
    // Contains user intent and browser metadata:
    //     {
    //     "type": "webauthn.get",
    //     "challenge": "<base64url>", // hello xxxx
    //     "origin": "<https://your-site>",
    //     ...
    //     }
    // The authenticator does NOT sign this JSON directly.
    // The browser computes: clientDataHash = SHA256(clientDataJSON)
    // Final signature:
    // ECDSA(P-256, SHA-256) over:
    //     authenticatorData || clientDataHash
    // Use the public key extracted from the credential (COSE_Key) to verify.
    func signMessage(_ message: String, anchor: ASPresentationAnchor, completion: @escaping (Result<SignatureResult, Error>) -> Void) {
        // 将消息作为 challenge
        guard let messageData = message.data(using: .utf8) else {
            completion(.failure(NSError(domain: "PasskeyManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid message"])))
            return
        }
        
        let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpID)
        let assertionRequest = platformProvider.createCredentialAssertionRequest(challenge: messageData)
        
        let authController = ASAuthorizationController(authorizationRequests: [assertionRequest])
        authController.delegate = self
        authController.presentationContextProvider = self
        authController.performRequests()
        
        self.signatureCompletion = completion
    }
    
    private func generateChallenge() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }
    
    private var registrationCompletion: ((Result<Data, Error>) -> Void)?
    private var authenticationCompletion: ((Result<Data, Error>) -> Void)?
    private var signatureCompletion: ((Result<SignatureResult, Error>) -> Void)?
}

// 签名结果
struct SignatureResult {
    let signature: Data
    let authenticatorData: Data
    let clientDataJSON: Data
    let challenge: Data
}

extension PasskeyManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration {
            // Passkey注册成功
            let credentialID = credential.credentialID
            self.currentCredentialID = credentialID.base64EncodedString()
            self.isAuthenticated = true
            
            // 保存 attestationObject
            if let attestationObject = credential.rawAttestationObject {
                self.attestationObject = attestationObject
                saveAttestationObject(attestationObject)
                
                // 从 attestationObject 中提取公钥
                if let publicKey = extractPublicKey(from: attestationObject) {
                    self.publicKey = publicKey
                    savePublicKey(publicKey)
                    print("✅ 成功提取 P256 公钥: \(publicKey.base64EncodedString())")
                } else {
                    print("❌ 无法从 attestationObject 提取公钥")
                }
            }
            
            // 保存credential ID
            saveCredentialID(credentialID)
            
            registrationCompletion?(.success(credentialID))
            registrationCompletion = nil
            
        } else if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
            // Passkey认证成功
            let credentialID = credential.credentialID
            self.currentCredentialID = credentialID.base64EncodedString()
            self.isAuthenticated = true
            
            // 保存签名数据
            self.lastSignature = credential.signature
            self.lastAuthenticatorData = credential.rawAuthenticatorData
            self.lastClientDataJSON = credential.rawClientDataJSON
            
            print("📝 签名数据:")
            print("  - Signature: \(credential.signature.base64EncodedString())")
            print("  - Authenticator Data: \(credential.rawAuthenticatorData.base64EncodedString())")
            print("  - Client Data JSON: \(String(data: credential.rawClientDataJSON, encoding: .utf8) ?? "N/A")")
            
            // 如果是签名请求
            if signatureCompletion != nil {
                let result = SignatureResult(
                    signature: credential.signature,
                    authenticatorData: credential.rawAuthenticatorData,
                    clientDataJSON: credential.rawClientDataJSON,
                    challenge: Data() // challenge 在 clientDataJSON 中
                )
                signatureCompletion?(.success(result))
                signatureCompletion = nil
            } else {
                authenticationCompletion?(.success(credentialID))
                authenticationCompletion = nil
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        registrationCompletion?(.failure(error))
        authenticationCompletion?(.failure(error))
        signatureCompletion?(.failure(error))
        registrationCompletion = nil
        authenticationCompletion = nil
        signatureCompletion = nil
    }
    
    private func saveCredentialID(_ credentialID: Data) {
        UserDefaults.standard.set(credentialID, forKey: "passkey_credential_id")
    }
    
    func getSavedCredentialID() -> Data? {
        return UserDefaults.standard.data(forKey: "passkey_credential_id")
    }
    
    private func saveAttestationObject(_ attestationObject: Data) {
        UserDefaults.standard.set(attestationObject, forKey: "passkey_attestation_object")
    }
    
    func getSavedAttestationObject() -> Data? {
        return UserDefaults.standard.data(forKey: "passkey_attestation_object")
    }
    
    private func savePublicKey(_ publicKey: Data) {
        UserDefaults.standard.set(publicKey, forKey: "passkey_public_key")
    }
    
    func getSavedPublicKey() -> Data? {
        return UserDefaults.standard.data(forKey: "passkey_public_key")
    }
    
    // 验证签名
    func verifySignature(signature: Data, authenticatorData: Data, clientDataJSON: Data, publicKey: Data) -> Bool {
        do {
            // 1. 计算 clientDataJSON 的 SHA-256 hash
            let clientDataHash = SHA256.hash(data: clientDataJSON)
            
            // 2. 构造签名数据: authenticatorData + clientDataHash
            var signedData = Data()
            signedData.append(authenticatorData)
            signedData.append(contentsOf: clientDataHash)
            
            // 3. 计算签名数据的 hash
            let signedDataHash = SHA256.hash(data: signedData)
            
            // 4. 从公钥创建 P256 公钥对象
            // 公钥格式: 0x04 + x(32字节) + y(32字节) = 65字节
            guard publicKey.count == 65 && publicKey[0] == 0x04 else {
                print("❌ 公钥格式错误")
                return false
            }
            
            let xCoord = publicKey[1..<33]
            let yCoord = publicKey[33..<65]
            
            // 创建 P256 公钥
            let p256PublicKey = try P256.Signing.PublicKey(x963Representation: publicKey)
            
            // 5. 验证签名
            // WebAuthn 使用 ASN.1 DER 编码的签名
            let ecdsaSignature = try P256.Signing.ECDSASignature(derRepresentation: signature)
            
            let isValid = p256PublicKey.isValidSignature(ecdsaSignature, for: signedDataHash)
            
            print("🔐 签名验证结果: \(isValid ? "✅ 有效" : "❌ 无效")")
            print("  - Signed data hash: \(signedDataHash.map { String(format: "%02x", $0) }.joined())")
            print("  - Signature (DER): \(signature.base64EncodedString())")
            
            return isValid
            
        } catch {
            print("❌ 签名验证失败: \(error.localizedDescription)")
            return false
        }
    }
    
    // 从 attestationObject 中提取 P256 公钥
    private func extractPublicKey(from attestationObject: Data) -> Data? {
        // attestationObject 是 CBOR 编码的数据
        // 结构: { "fmt": "...", "attStmt": {...}, "authData": [...] }
        // authData 包含: rpIdHash (32字节) + flags (1字节) + signCount (4字节) + attestedCredentialData
        // attestedCredentialData 包含: aaguid (16字节) + credentialIdLength (2字节) + credentialId + credentialPublicKey (CBOR)
        
        guard let cbor = try? CBOR.decode(attestationObject) else {
            print("❌ 无法解码 attestationObject CBOR")
            return nil
        }
        
        guard case let .map(cborMap) = cbor,
              let authDataCBOR = cborMap[.text("authData")],
              case let .byteString(authData) = authDataCBOR else {
            print("❌ 无法从 CBOR 获取 authData")
            return nil
        }
        
        // 解析 authData
        // 前 37 字节: rpIdHash (32) + flags (1) + signCount (4)
        guard authData.count > 37 else {
            print("❌ authData 长度不足")
            return nil
        }
        
        let flags = authData[32]
        let hasAttestedCredentialData = (flags & 0x40) != 0
        
        guard hasAttestedCredentialData else {
            print("❌ authData 不包含 attestedCredentialData")
            return nil
        }
        
        // 跳过前 37 字节，开始解析 attestedCredentialData
        var offset = 37
        
        // AAGUID (16 字节)
        offset += 16
        
        // Credential ID Length (2 字节, big-endian)
        guard authData.count >= offset + 2 else {
            print("❌ authData 长度不足以读取 credentialIdLength")
            return nil
        }
        let credentialIdLength = Int(authData[offset]) << 8 | Int(authData[offset + 1])
        offset += 2
        
        // Credential ID
        offset += credentialIdLength
        
        // Credential Public Key (CBOR 编码)
        guard authData.count > offset else {
            print("❌ authData 长度不足以读取 credentialPublicKey")
            return nil
        }
        
        let publicKeyCBOR = Data(authData[offset...])
        guard let publicKeyMap = try? CBOR.decode(publicKeyCBOR),
              case let .map(pkMap) = publicKeyMap else {
            print("❌ 无法解码 credentialPublicKey CBOR")
            return nil
        }
        
        // 调试：打印所有的 key
        print("📊 COSE Key Map 内容:")
        for (key, value) in pkMap {
            print("  Key: \(key), Value type: \(value)")
        }
        
        // COSE Key 格式
        // kty (1): 2 (EC2)
        // alg (3): -7 (ES256)
        // crv (-1): 1 (P-256)
        // x (-2): x 坐标 (32 字节)
        // y (-3): y 坐标 (32 字节)
        
        // CBOR 负整数编码: negativeInt(n) = -(n+1)
        // 所以 -2 = negativeInt(1), -3 = negativeInt(2)
        guard let xCBOR = pkMap[.negativeInt(1)], // -2
              case let .byteString(xCoord) = xCBOR,
              let yCBOR = pkMap[.negativeInt(2)], // -3
              case let .byteString(yCoord) = yCBOR else {
            print("❌ 无法从 COSE Key 提取 x, y 坐标")
            print("  尝试查找的 keys: negativeInt(1) for x, negativeInt(2) for y")
            return nil
        }
        
        print("✅ 成功提取坐标:")
        print("  x: \(xCoord.count) 字节")
        print("  y: \(yCoord.count) 字节")
        
        // P-256 公钥格式: 0x04 + x (32字节) + y (32字节)
        var publicKey = Data([0x04])
        publicKey.append(contentsOf: xCoord)
        publicKey.append(contentsOf: yCoord)
        
        return publicKey
    }
}

// 简单的 CBOR 解码器
enum CBOR {
    case unsignedInt(UInt64)
    case negativeInt(UInt64)
    case byteString(Data)
    case text(String)
    case array([CBOR])
    case map([CBOR: CBOR])
    case bool(Bool)
    case null
    
    static func decode(_ data: Data) throws -> CBOR {
        var offset = 0
        return try decode(data, offset: &offset)
    }
    
    private static func decode(_ data: Data, offset: inout Int) throws -> CBOR {
        guard offset < data.count else {
            throw NSError(domain: "CBOR", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unexpected end of data"])
        }
        
        let initialByte = data[offset]
        offset += 1
        
        let majorType = initialByte >> 5
        let additionalInfo = initialByte & 0x1F
        
        switch majorType {
        case 0: // Unsigned integer
            let value = try readUInt(data: data, offset: &offset, additionalInfo: additionalInfo)
            return .unsignedInt(value)
            
        case 1: // Negative integer
            let value = try readUInt(data: data, offset: &offset, additionalInfo: additionalInfo)
            return .negativeInt(value)
            
        case 2: // Byte string
            let length = try readLength(data: data, offset: &offset, additionalInfo: additionalInfo)
            let bytes = data[offset..<offset+length]
            offset += length
            return .byteString(Data(bytes))
            
        case 3: // Text string
            let length = try readLength(data: data, offset: &offset, additionalInfo: additionalInfo)
            let bytes = data[offset..<offset+length]
            offset += length
            if let string = String(data: Data(bytes), encoding: .utf8) {
                return .text(string)
            }
            throw NSError(domain: "CBOR", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid UTF-8"])
            
        case 4: // Array
            let count = try readLength(data: data, offset: &offset, additionalInfo: additionalInfo)
            var array: [CBOR] = []
            for _ in 0..<count {
                array.append(try decode(data, offset: &offset))
            }
            return .array(array)
            
        case 5: // Map
            let count = try readLength(data: data, offset: &offset, additionalInfo: additionalInfo)
            var map: [CBOR: CBOR] = [:]
            for _ in 0..<count {
                let key = try decode(data, offset: &offset)
                let value = try decode(data, offset: &offset)
                map[key] = value
            }
            return .map(map)
            
        case 7: // Special
            switch additionalInfo {
            case 20: return .bool(false)
            case 21: return .bool(true)
            case 22: return .null
            default:
                throw NSError(domain: "CBOR", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unsupported special value"])
            }
            
        default:
            throw NSError(domain: "CBOR", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unsupported major type"])
        }
    }
    
    private static func readUInt(data: Data, offset: inout Int, additionalInfo: UInt8) throws -> UInt64 {
        if additionalInfo < 24 {
            return UInt64(additionalInfo)
        } else if additionalInfo == 24 {
            let value = data[offset]
            offset += 1
            return UInt64(value)
        } else if additionalInfo == 25 {
            let value = UInt16(data[offset]) << 8 | UInt16(data[offset+1])
            offset += 2
            return UInt64(value)
        } else if additionalInfo == 26 {
            let value = UInt32(data[offset]) << 24 | UInt32(data[offset+1]) << 16 | UInt32(data[offset+2]) << 8 | UInt32(data[offset+3])
            offset += 4
            return UInt64(value)
        } else if additionalInfo == 27 {
            var value: UInt64 = 0
            for i in 0..<8 {
                value = (value << 8) | UInt64(data[offset+i])
            }
            offset += 8
            return value
        }
        throw NSError(domain: "CBOR", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid additional info"])
    }
    
    private static func readLength(data: Data, offset: inout Int, additionalInfo: UInt8) throws -> Int {
        return Int(try readUInt(data: data, offset: &offset, additionalInfo: additionalInfo))
    }
}

extension CBOR: Hashable {
    func hash(into hasher: inout Hasher) {
        switch self {
        case .unsignedInt(let v): hasher.combine(v)
        case .negativeInt(let v): hasher.combine(v)
        case .byteString(let v): hasher.combine(v)
        case .text(let v): hasher.combine(v)
        case .bool(let v): hasher.combine(v)
        case .null: hasher.combine(0)
        case .array, .map: hasher.combine(0) // 简化处理
        }
    }
    
    static func == (lhs: CBOR, rhs: CBOR) -> Bool {
        switch (lhs, rhs) {
        case (.unsignedInt(let l), .unsignedInt(let r)): return l == r
        case (.negativeInt(let l), .negativeInt(let r)): return l == r
        case (.byteString(let l), .byteString(let r)): return l == r
        case (.text(let l), .text(let r)): return l == r
        case (.bool(let l), .bool(let r)): return l == r
        case (.null, .null): return true
        default: return false
        }
    }
}

extension PasskeyManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}
