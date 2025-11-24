//
//  CameraView.swift
//  Polarwing
//
//  Created on 2025-11-24.
//

import SwiftUI
import AVFoundation
import UIKit
import Photos
import CoreMotion

struct CameraView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var cameraManager = CameraManager()
    @State private var capturedImage: UIImage?
    @State private var showImagePreview = false
    @State private var showPhotoGallery = false
    var onDismiss: (() -> Void)? = nil
    var onImageCaptured: ((UIImage) -> Void)? = nil
    var mode: CameraMode = .continuous  // 默认为连续拍摄模式
    
    enum CameraMode {
        case continuous  // Camera 标签模式：拍照后继续拍
        case singleShot  // New Post 模式：拍照后确认
    }
    
    // 计算UI元素的旋转角度
    private var rotationAngle: Angle {
        switch cameraManager.deviceOrientation {
        case .portrait:
            return .degrees(0)
        case .portraitUpsideDown:
            return .degrees(180)
        case .landscapeLeft:
            return .degrees(90)
        case .landscapeRight:
            return .degrees(-90)
        default:
            return .degrees(0)
        }
    }
    
    var body: some View {
        ZStack {
            // 相机预览
            if !showImagePreview {
                CameraPreview(session: cameraManager.session)
                    .ignoresSafeArea()
                    .onAppear {
                        // 确保相机会话正在运行
                        if !cameraManager.session.isRunning {
                            DispatchQueue.global(qos: .userInitiated).async {
                                cameraManager.session.startRunning()
                            }
                        }
                    }
                
                VStack {
                    // 顶部工具栏
                    HStack {
                        Button(action: {
                            if let onDismiss = onDismiss {
                                onDismiss()
                            } else {
                                dismiss()
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        // 闪光灯按钮
                        Button(action: {
                            cameraManager.toggleFlash()
                        }) {
                            Image(systemName: cameraManager.flashMode == .on ? "bolt.fill" : "bolt.slash.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    // 底部控制栏
                    HStack(spacing: 0) {
                        // 左侧：相册预览
                        Button(action: {
                            showPhotoGallery = true
                        }) {
                            if let lastImage = cameraManager.lastPhotoThumbnail {
                                Image(uiImage: lastImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 50, height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white, lineWidth: 2)
                                    )
                            } else {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                            }
                        }
                        .rotationEffect(rotationAngle)
                        .animation(.easeInOut(duration: 0.3), value: rotationAngle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // 拍照按钮
                        Button(action: {
                            cameraManager.capturePhoto { image in
                                if let image = image {
                                    capturedImage = image
                                    // 根据模式决定是否显示预览
                                    if mode == .singleShot {
                                        showImagePreview = true
                                    }
                                }
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 172/255, green: 237/255, blue: 228/255))
                                    .frame(width: 70, height: 70)
                                
                                Circle()
                                    .stroke(Color.white, lineWidth: 3)
                                    .frame(width: 80, height: 80)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        // 右侧：切换摄像头
                        Button(action: {
                            cameraManager.switchCamera()
                        }) {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                        }
                        .rotationEffect(rotationAngle)
                        .animation(.easeInOut(duration: 0.3), value: rotationAngle)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 40)
                }
            } else if let image = capturedImage {
                // 图片预览
                ImagePreviewView(
                    image: image,
                    onRetake: {
                        showImagePreview = false
                        capturedImage = nil
                    },
                    onUse: {
                        if let onImageCaptured = onImageCaptured {
                            onImageCaptured(image)
                        }
                        if let onDismiss = onDismiss {
                            onDismiss()
                        } else {
                            dismiss()
                        }
                    }
                )
            }
        }
        .onAppear {
            cameraManager.checkPermissions()
        }
        .alert("需要相机权限", isPresented: $cameraManager.showPermissionAlert) {
            Button("去设置", role: .none) {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("取消", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("请在设置中允许 Polarwing 访问相机")
        }
        .fullScreenCover(isPresented: $showPhotoGallery) {
            PhotoGalleryView()
        }
    }
}

// 相机预览视图
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    class PreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        
        DispatchQueue.global(qos: .userInitiated).async {
            if !session.isRunning {
                session.startRunning()
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        // PreviewLayer 会自动调整大小
    }
}

// 图片预览视图
struct ImagePreviewView: View {
    let image: UIImage
    let onRetake: () -> Void
    let onUse: () -> Void
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
            
            VStack {
                Spacer()
                
                HStack(spacing: 40) {
                    Button(action: onRetake) {
                        VStack {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.title2)
                            Text("重拍")
                                .font(.caption)
                        }
                        .foregroundColor(Color(red: 172/255, green: 237/255, blue: 228/255))
                    }
                    
                    Button(action: onUse) {
                        VStack {
                            Image(systemName: "checkmark")
                                .font(.title2)
                            Text("使用")
                                .font(.caption)
                        }
                        .foregroundColor(Color(red: 172/255, green: 237/255, blue: 228/255))
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
}

// 相机管理器
class CameraManager: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var showPermissionAlert = false
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var lastPhotoThumbnail: UIImage?
    @Published var deviceOrientation: UIDeviceOrientation = .portrait  // 改为 @Published 以便 UI 响应
    
    private var photoOutput = AVCapturePhotoOutput()
    private var currentCamera: AVCaptureDevice?
    private var captureCompletion: ((UIImage?) -> Void)?
    private let motionManager = CMMotionManager()
    
    override init() {
        super.init()
        loadLastPhotoThumbnail()
        startMonitoringDeviceOrientation()
    }
    
    deinit {
        stopMonitoringDeviceOrientation()
    }
    
    // 开始监听设备方向
    private func startMonitoringDeviceOrientation() {
        guard motionManager.isAccelerometerAvailable else {
            print("⚠️ 加速度计不可用")
            return
        }
        
        motionManager.accelerometerUpdateInterval = 0.2
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else { return }
            
            let acceleration = data.acceleration
            let threshold = 0.5  // 设置阈值避免抖动
            
            // 根据加速度计数据判断设备方向
            if abs(acceleration.y) > abs(acceleration.x) && abs(acceleration.y) > threshold {
                if acceleration.y > 0 {
                    if self.deviceOrientation != .portraitUpsideDown {
                        self.deviceOrientation = .portraitUpsideDown
                    }
                } else {
                    if self.deviceOrientation != .portrait {
                        self.deviceOrientation = .portrait
                    }
                }
            } else if abs(acceleration.x) > threshold {
                if acceleration.x > 0 {
                    if self.deviceOrientation != .landscapeRight {
                        self.deviceOrientation = .landscapeRight
                    }
                } else {
                    if self.deviceOrientation != .landscapeLeft {
                        self.deviceOrientation = .landscapeLeft
                    }
                }
            }
        }
    }
    
    // 停止监听设备方向
    private func stopMonitoringDeviceOrientation() {
        motionManager.stopAccelerometerUpdates()
    }
    
    // 获取照片方向
    private func getPhotoOrientation() -> CGImagePropertyOrientation {
        // 根据设备方向和相机位置返回正确的照片方向
        let isUsingFrontCamera = currentCamera?.position == .front
        
        switch deviceOrientation {
        case .portrait:
            return .right
        case .portraitUpsideDown:
            return .left
        case .landscapeLeft:
            return isUsingFrontCamera ? .down : .up
        case .landscapeRight:
            return isUsingFrontCamera ? .up : .down
        default:
            return .right
        }
    }
    
    private func loadLastPhotoThumbnail() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            guard status == .authorized || status == .limited else {
                return
            }
            
            self?.getOrCreatePolarwingAlbum { collection in
                guard let collection = collection else {
                    return
                }
                
                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                fetchOptions.fetchLimit = 1
                
                let fetchResult = PHAsset.fetchAssets(in: collection, options: fetchOptions)
                
                guard let lastAsset = fetchResult.firstObject else {
                    return
                }
                
                let imageManager = PHImageManager.default()
                let targetSize = CGSize(width: 100, height: 100)
                let options = PHImageRequestOptions()
                options.isSynchronous = false
                options.deliveryMode = .highQualityFormat
                
                imageManager.requestImage(for: lastAsset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, _ in
                    DispatchQueue.main.async {
                        self?.lastPhotoThumbnail = image
                    }
                }
            }
        }
    }
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.setupCamera()
                    }
                }
            }
        default:
            DispatchQueue.main.async {
                self.showPermissionAlert = true
            }
        }
    }
    
    private func setupCamera() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                self.session.commitConfiguration()
                return
            }
            
            self.currentCamera = camera
            
            do {
                let input = try AVCaptureDeviceInput(device: camera)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
                
                if self.session.canAddOutput(self.photoOutput) {
                    self.session.addOutput(self.photoOutput)
                }
                
                self.session.sessionPreset = .photo
                self.session.commitConfiguration()
                
                print("✅ 相机设置成功")
            } catch {
                print("❌ 相机设置错误: \(error.localizedDescription)")
                self.session.commitConfiguration()
            }
        }
    }
    
    func switchCamera() {
        session.beginConfiguration()
        
        guard let currentInput = session.inputs.first as? AVCaptureDeviceInput else {
            return
        }
        
        session.removeInput(currentInput)
        
        let newPosition: AVCaptureDevice.Position = currentInput.device.position == .back ? .front : .back
        
        guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
            return
        }
        
        currentCamera = newCamera
        
        do {
            let newInput = try AVCaptureDeviceInput(device: newCamera)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
            }
        } catch {
            print("切换相机错误: \(error.localizedDescription)")
        }
        
        session.commitConfiguration()
    }
    
    func toggleFlash() {
        flashMode = flashMode == .off ? .on : .off
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        self.captureCompletion = completion
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode
        
        // 设置照片方向信息
        if let connection = photoOutput.connection(with: .video) {
            connection.videoOrientation = convertDeviceOrientationToVideoOrientation(deviceOrientation)
        }
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // 转换设备方向为视频方向
    private func convertDeviceOrientationToVideoOrientation(_ orientation: UIDeviceOrientation) -> AVCaptureVideoOrientation {
        switch orientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft
        default:
            return .portrait
        }
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("拍照错误: \(error.localizedDescription)")
            captureCompletion?(nil)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            captureCompletion?(nil)
            return
        }
        
        // 使用 CGImageSource 读取照片并保留 EXIF 信息
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            captureCompletion?(nil)
            return
        }
        
        // 创建带正确方向的 UIImage
        let photoOrientation = getPhotoOrientation()
        let uiImageOrientation = convertToUIImageOrientation(photoOrientation)
        let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: uiImageOrientation)
        
        // 保存到相册时保留方向信息
        savePhotoToLibraryWithOrientation(imageData: imageData, orientation: photoOrientation)
        
        captureCompletion?(image)
    }
    
    // 转换 CGImagePropertyOrientation 为 UIImage.Orientation
    private func convertToUIImageOrientation(_ cgOrientation: CGImagePropertyOrientation) -> UIImage.Orientation {
        switch cgOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        }
    }
    
    // 保存照片到相册并保留方向信息
    private func savePhotoToLibraryWithOrientation(imageData: Data, orientation: CGImagePropertyOrientation) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                print("⚠️ 没有相册写入权限")
                return
            }
            
            // 获取或创建 Polarwing 专属相册
            self.getOrCreatePolarwingAlbum { collection in
                guard let collection = collection else {
                    print("❌ 无法创建相册")
                    return
                }
                
                // 创建带有方向信息的照片数据
                guard let imageDataWithOrientation = self.createImageDataWithOrientation(imageData: imageData, orientation: orientation) else {
                    print("❌ 无法创建带方向信息的图片数据")
                    return
                }
                
                PHPhotoLibrary.shared().performChanges({
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    creationRequest.addResource(with: .photo, data: imageDataWithOrientation, options: nil)
                    
                    if let assetPlaceholder = creationRequest.placeholderForCreatedAsset,
                       let albumChangeRequest = PHAssetCollectionChangeRequest(for: collection) {
                        albumChangeRequest.addAssets([assetPlaceholder] as NSArray)
                    }
                }) { success, error in
                    if success {
                        print("✅ 照片已保存到 Polarwing 相册，方向: \(orientation.rawValue)")
                        // 更新缩略图
                        if let image = UIImage(data: imageDataWithOrientation) {
                            DispatchQueue.main.async {
                                self.lastPhotoThumbnail = image
                            }
                        }
                    } else if let error = error {
                        print("❌ 保存到相册失败: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    // 创建带有正确 EXIF 方向信息的图片数据
    private func createImageDataWithOrientation(imageData: Data, orientation: CGImagePropertyOrientation) -> Data? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let uti = CGImageSourceGetType(source) else {
            return nil
        }
        
        let destinationData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(destinationData, uti, 1, nil) else {
            return nil
        }
        
        // 复制原始图片的元数据
        var properties: [String: Any] = [:]
        if let imageProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
            properties = imageProperties
        }
        
        // 设置正确的方向
        properties[kCGImagePropertyOrientation as String] = orientation.rawValue
        
        // 添加图片到目标
        CGImageDestinationAddImageFromSource(destination, source, 0, properties as CFDictionary)
        
        // 完成写入
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        return destinationData as Data
    }
    
    private func getOrCreatePolarwingAlbum(completion: @escaping (PHAssetCollection?) -> Void) {
        let albumName = "Polarwing"
        
        // 查找已存在的相册
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        
        if let collection = collections.firstObject {
            completion(collection)
            return
        }
        
        // 创建新相册
        var placeholder: PHObjectPlaceholder?
        PHPhotoLibrary.shared().performChanges({
            let createAlbumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
            placeholder = createAlbumRequest.placeholderForCreatedAssetCollection
        }) { success, error in
            if success, let placeholder = placeholder {
                let collections = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
                completion(collections.firstObject)
            } else {
                print("❌ 创建相册失败: \(error?.localizedDescription ?? "未知错误")")
                completion(nil)
            }
        }
    }
}
