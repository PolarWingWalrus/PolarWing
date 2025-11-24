//
//  ContentView.swift
//  Polarwing
//
//  Created by Harold on 2025/11/22.
//

import SwiftUI

struct ContentView: View {
    @State private var isOnboardingComplete = UserDefaults.standard.string(forKey: "username") != nil
    
    var body: some View {
        if isOnboardingComplete {
            MainTabView()
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReturnToOnboarding"))) { _ in
                    // 返回到 Onboarding 页面
                    isOnboardingComplete = false
                }
        } else {
            OnboardingView(isOnboardingComplete: $isOnboardingComplete)
        }
    }
}

#Preview {
    ContentView()
}
