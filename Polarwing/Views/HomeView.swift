//
//  HomeView.swift
//  Polarwing
//
//  Created on 2025-11-22.
//

import SwiftUI

struct HomeView: View {
    @State private var posts: [Post] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    VStack {
                        ProgressView()
                            .padding()
                        Text("加载帖子中...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("加载失败")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("重试") {
                            loadPosts()
                        }
                        .padding(.horizontal, 30)
                        .padding(.vertical, 10)
                        .background(Color(red: 172/255, green: 237/255, blue: 228/255))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                } else if posts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("暂无帖子")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                } else {
                    PostGridView(posts: posts, showUsername: true)
                }
            }
            .navigationTitle("Polarwing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: loadPosts) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(Color(red: 172/255, green: 237/255, blue: 228/255))
                    }
                    .disabled(isLoading)
                }
            }
            .onAppear {
                if posts.isEmpty {
                    loadPosts()
                }
            }
        }
    }
    
    private func loadPosts() {
        // 获取当前用户地址（如果有的话）
        let suiAddress = UserDefaults.standard.string(forKey: "suiAddress") ?? ""
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // 获取所有公开可见的帖子
                let postsPage = try await APIService.shared.getPosts(
                    scope: "all",
                    page: 1,
                    pageSize: 50,
                    includeContent: false,
                    suiAddress: suiAddress
                )
                
                // 获取每个帖子的详细内容
                var allPosts = postsPage.posts
                
                for i in 0..<allPosts.count {
                    // 如果帖子是 Walrus 存储且没有 contentTitle，则获取详细内容
                    if allPosts[i].storageType == "walrus" && allPosts[i].contentTitle == nil {
                        do {
                            let content = try await APIService.shared.getPostContent(
                                postId: allPosts[i].id,
                                suiAddress: suiAddress
                            )
                            
                            // 更新帖子内容
                            allPosts[i].title = content.title
                            allPosts[i].content = content.content
                            allPosts[i].mediaUrls = content.mediaUrls
                            
                            print("✅ 获取帖子 \(allPosts[i].id) 的内容: \(content.title)")
                        } catch {
                            print("⚠️ 获取帖子 \(allPosts[i].id) 内容失败: \(error.localizedDescription)")
                            // 继续处理其他帖子
                        }
                    }
                }
                
                await MainActor.run {
                    self.posts = allPosts
                    self.isLoading = false
                    print("✅ 成功加载 \(allPosts.count) 个帖子")
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                    print("❌ 加载帖子失败: \(error.localizedDescription)")
                }
            }
        }
    }
}
