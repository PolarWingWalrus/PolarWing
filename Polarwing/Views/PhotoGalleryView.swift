//
//  PhotoGalleryView.swift
//  Polarwing
//
//  Created on 2025-11-24.
//

import SwiftUI
import Photos

struct PhotoGalleryView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = PhotoGalleryViewModel()
    @State private var selectedAsset: PHAsset?
    
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
                        Text("没有照片")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(viewModel.photoAssets, id: \.localIdentifier) { asset in
                                GeometryReader { geometry in
                                    ThumbnailView(asset: asset)
                                        .frame(width: geometry.size.width, height: geometry.size.width)
                                }
                                .aspectRatio(1, contentMode: .fit)
                                .clipped()
                                .onTapGesture {
                                    selectedAsset = asset
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
            }
            .navigationTitle("相册")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(Color(red: 172/255, green: 237/255, blue: 228/255))
                    }
                }
            }
            .fullScreenCover(item: $selectedAsset) { asset in
                PhotoDetailView(asset: asset, allAssets: viewModel.photoAssets)
            }
        }
        .onAppear {
            viewModel.loadPhotos()
        }
    }
}

// MARK: - 缩略图视图
struct ThumbnailView: View {
    let asset: PHAsset
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
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
            self.image = image
        }
    }
}

// MARK: - 照片详情视图（支持缩放）
struct PhotoDetailView: View {
    @Environment(\.dismiss) var dismiss
    let asset: PHAsset
    let allAssets: [PHAsset]
    
    @State private var currentAsset: PHAsset
    @State private var image: UIImage?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isLoading = true
    
    init(asset: PHAsset, allAssets: [PHAsset]) {
        self.asset = asset
        self.allAssets = allAssets
        _currentAsset = State(initialValue: asset)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else if let image = image {
                GeometryReader { geometry in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale *= delta
                                    scale = min(max(scale, 1.0), 5.0)
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                    if scale < 1.0 {
                                        withAnimation(.spring()) {
                                            scale = 1.0
                                            offset = .zero
                                        }
                                    }
                                }
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if scale > 1.0 {
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring()) {
                                if scale > 1.0 {
                                    scale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 2.0
                                }
                            }
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            
            // 顶部工具栏
            VStack {
                HStack {
                    Button(action: {
                        // 返回相册列表
                        dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                }
                .padding()
                
                Spacer()
            }
        }
        .statusBar(hidden: true)
        .onAppear {
            loadFullImage()
        }
        .onChange(of: currentAsset) { _, newAsset in
            loadFullImage()
        }
    }
    
    private func loadFullImage() {
        isLoading = true
        image = nil
        scale = 1.0
        offset = .zero
        lastOffset = .zero
        
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        // 根据屏幕尺寸请求合适大小的图片，避免内存问题
        let screenScale = UIScreen.main.scale
        let screenSize = UIScreen.main.bounds.size
        let targetSize = CGSize(
            width: screenSize.width * screenScale,
            height: screenSize.height * screenScale
        )
        
        imageManager.requestImage(
            for: currentAsset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { image, info in
            if let image = image {
                self.image = image
                self.isLoading = false
            }
        }
    }
}

// MARK: - ViewModel
class PhotoGalleryViewModel: ObservableObject {
    @Published var photoAssets: [PHAsset] = []
    
    func loadPhotos() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            guard status == .authorized || status == .limited else {
                return
            }
            
            DispatchQueue.main.async {
                self?.fetchPhotos()
            }
        }
    }
    
    private func fetchPhotos() {
        // 获取 Polarwing 专属相册
        let albumName = "Polarwing"
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        
        guard let collection = collections.firstObject else {
            print("⚠️ Polarwing 相册不存在")
            return
        }
        
        let assetFetchOptions = PHFetchOptions()
        assetFetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let fetchResult = PHAsset.fetchAssets(in: collection, options: assetFetchOptions)
        
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        
        photoAssets = assets
    }
}

// 扩展 PHAsset 使其符合 Identifiable
extension PHAsset: Identifiable {
    public var id: String {
        return localIdentifier
    }
}
