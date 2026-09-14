//
//  MacCQApp.swift
//  MacCQ
//

import SwiftUI

@main
struct MacCQApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
        .windowResizability(.contentMinSize)
        .commands {
            SidebarCommands()
        }
    }
}

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

/// 登录 / 注册：仅需输入用户名（英文、数字，唯一），首次使用自动创建账号。
struct LoginView: View {
    @Environment(AppState.self) private var appState
    @State private var username = ""
    @State private var users: [User] = []

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()

            VStack(spacing: 26) {
                VStack(spacing: 10) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Text("MacCQ")
                        .font(Theme.font(24, .bold))
                    Text("业余无线电操作证练习")
                        .font(Theme.body)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("用户名").font(Theme.label)
                    TextField("英文或数字，例如 wang123", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .font(Theme.body)
                        .onSubmit { submit() }

                    if let error = appState.loginError {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .font(Theme.caption)
                            .foregroundStyle(Theme.danger)
                    }

                    Button {
                        submit()
                    } label: {
                        Text("登录 / 注册")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryActionButton())
                    .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Text("首次使用会自动创建账号；题库共享，错题、收藏、练习进度等按用户分别保存。")
                        .font(Theme.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 360)
                .card(padding: 24)

                if !users.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("已有账号").font(Theme.label).foregroundStyle(.secondary)
                        FlowLayout(spacing: 8) {
                            ForEach(users) { user in
                                Button {
                                    username = user.username
                                    submit()
                                } label: {
                                    Text(user.username)
                                        .font(Theme.font(13, .medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Theme.surface, in: Capsule())
                                        .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxWidth: 360, alignment: .leading)
                }
            }
            .padding(40)
            .frame(maxWidth: 520)
        }
        .frame(minWidth: 720, minHeight: 520)
        .onAppear { users = appState.loadUsers() }
    }

    private func submit() {
        guard appState.login(username: username) else { return }
        username = ""
    }
}
