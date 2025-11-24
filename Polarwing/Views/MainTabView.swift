//
//  MainTabView.swift
//  Polarwing
//
//  Created on 2025-11-22.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var previousTab = 0
    @State private var showCreatePostMenu = false
    @State private var showCamera = false
    @State private var showPhotoGallery = false
    @State private var selectedImage: UIImage?
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Explore (原 Home)
            HomeView()
                .tag(0)
                .tabItem {
                    Image(systemName: "safari")
                    Text("Explore")
                }
                .toolbarBackground(.black, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
            
            // Camera
            CameraTabView(onDismiss: {
                selectedTab = previousTab
            })
            .tag(1)
            .tabItem {
                Image(systemName: "camera")
                Text("Camera")
            }
            
            // New Post (占位符，实际使用 sheet)
            Color.clear
                .tag(2)
                .tabItem {
                    Image(systemName: "paperplane")
                    Text("New Post")
                }
            
            // Me
            ProfileView()
                .tag(3)
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Me")
                }
                .toolbarBackground(.black, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
        .tint(Color(red: 172/255, green: 237/255, blue: 228/255))
        .toolbarBackground(.black, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == 2 {
                // 点击 New Post 时显示底部菜单
                showCreatePostMenu = true
                // 返回到之前的 tab
                selectedTab = previousTab
            } else if newValue != 1 {
                previousTab = newValue
            }
        }
        .confirmationDialog("选择发帖方式", isPresented: $showCreatePostMenu, titleVisibility: .visible) {
            Button("拍摄") {
                showCamera = true
            }
            Button("从相册选择") {
                showPhotoGallery = true
            }
            Button("取消", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(onImageCaptured: { image in
                selectedImage = image
                showCamera = false
                // 使用 DispatchQueue 确保状态更新完成后再显示 sheet
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // selectedImage 已经设置好了
                }
            }, mode: .singleShot)  // New Post 模式：拍照后确认
        }
        .fullScreenCover(isPresented: $showPhotoGallery) {
            PhotoGalleryPickerView { image in
                selectedImage = image
                showPhotoGallery = false
                // 使用 DispatchQueue 确保状态更新完成后再显示 sheet
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // selectedImage 已经设置好了
                }
            }
        }
        .sheet(item: Binding(
            get: { selectedImage.map { ImageWrapper(image: $0) } },
            set: { newValue in
                if newValue == nil {
                    selectedImage = nil
                }
            }
        )) { wrapper in
            CreatePostWithImageView(image: wrapper.image)
        }
    }
}

// 相机标签页的包装视图
struct CameraTabView: View {
    let onDismiss: () -> Void
    
    var body: some View {
        CameraView(onDismiss: onDismiss, mode: .continuous)  // Camera 标签模式：连续拍摄
            .toolbar(.hidden, for: .tabBar)
    }
}

// 用于 sheet(item:) 的包装器
struct ImageWrapper: Identifiable {
    let id = UUID()
    let image: UIImage
}
