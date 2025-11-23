//
//  MainTabView.swift
//  Polarwing
//
//  Created on 2025-11-22.
//

import SwiftUI

struct MainTabView: View {
    @State private var showCreatePost = false
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tag(0)
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Home")
                    }
                
                Color.clear
                    .tag(1)
                    .tabItem {
                        Image(systemName: "circle")
                        Text("")
                    }
                
                ProfileView()
                    .tag(2)
                    .tabItem {
                        Image(systemName: "person.fill")
                        Text("Me")
                    }
            }
            .tint(Color(red: 172/255, green: 237/255, blue: 228/255))
            .onChange(of: selectedTab) { oldValue, newValue in
                if newValue == 1 {
                    showCreatePost = true
                    // 延迟重置，避免闪烁
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        selectedTab = oldValue
                    }
                }
            }
            
            // 自定义加号按钮
            Button(action: {
                showCreatePost = true
            }) {
                ZStack {
                    Circle()
                        .fill(Color(red: 172/255, green: 237/255, blue: 228/255))
                        .frame(width: 56, height: 56)
                        .shadow(color: Color(red: 172/255, green: 237/255, blue: 228/255).opacity(0.5), radius: 10, x: 0, y: 5)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .offset(y: -20)
        }
        .fullScreenCover(isPresented: $showCreatePost) {
            CameraView()
        }
    }
}
