//
//  RootView.swift
//  MacCQ
//

import SwiftUI

/// 应用根视图：未登录时显示登录页，登录后进入主界面。
struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if appState.currentUser != nil {
            MainView()
        } else {
            LoginView()
        }
    }
}
