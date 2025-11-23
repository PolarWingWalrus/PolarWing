//
//  CreatePostView.swift
//  Polarwing
//
//  Created on 2025-11-22.
//

import SwiftUI
import PhotosUI

struct CreatePostView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedImage: UIImage?
    @State private var caption = ""
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let image = selectedImage {
                    // 显示选中的图片
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .cornerRadius(12)
                    
                    // 图片说明输入框
                    TextField("添加图片说明...", text: $caption, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .lineLimit(3...6)
                    
                    Spacer()
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
                                Text("拍照")
                                    .font(.headline)
                            }
                            .foregroundColor(Color(red: 172/255, green: 237/255, blue: 228/255))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .background(Color(red: 172/255, green: 237/255, blue: 228/255).opacity(0.1))
                            .cornerRadius(16)
                        }
                        
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            VStack(spacing: 12) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 50))
                                Text("从相册选择")
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
            .navigationTitle("发帖")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                if selectedImage != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("发布") {
                            // TODO: 发布帖子
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView()
            }
            .onChange(of: selectedPhotoItem) { oldValue, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                    }
                }
            }
        }
    }
}
