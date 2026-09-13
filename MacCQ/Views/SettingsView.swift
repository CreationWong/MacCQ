//
//  SettingsView.swift
//  MacCQ
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var model = ""
    @State private var saved = false
    @State private var showClearChatConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                accountSection
                aiSection
                chatSection
                bankSection
                privacyNote
            }
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 28)
            .padding(.vertical, 32)
        }
        .pageBackground()
        .navigationTitle("设置")
        .onAppear { load() }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("账号").font(Theme.sectionTitle)

            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.currentUser?.username ?? "未登录")
                        .font(Theme.font(15, .semibold))
                    Text("错题、收藏、练习进度、成绩与对话都保存在该账号下")
                        .font(Theme.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("切换用户") {
                    appState.logout()
                }
                .buttonStyle(SecondaryActionButton())
            }
        }
        .card(padding: 20)
    }

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("智能答疑").font(Theme.sectionTitle)
                Text("填写服务信息后，就可以在答题时请 AI 帮你讲解题目。")
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
            }

            labeledField("服务地址", hint: "由你使用的 AI 服务提供方给出") {
                TextField("", text: $baseURL)
                    .textFieldStyle(.roundedBorder)
            }
            labeledField("访问密钥", hint: "用于验证你的账号") {
                SecureField("", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
            }
            labeledField("模型名称", hint: "填写服务方提供的模型名称") {
                TextField("", text: $model)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 12) {
                Button("保存") { save() }
                    .buttonStyle(PrimaryActionButton())
                    .disabled(baseURL.isEmpty || apiKey.isEmpty || model.isEmpty)

                if saved {
                    Label("已保存", systemImage: "checkmark.circle.fill")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.success)
                }
                Spacer()
            }
        }
        .card(padding: 20)
    }

    private var chatSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("对话记录").font(Theme.sectionTitle)
                Text("保留与 AI 的对话，下次打开可以接着看；关闭后不再保存新的对话。")
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("保留对话记录", isOn: Binding(
                get: { appState.keepChatHistory },
                set: { appState.setKeepChatHistory($0) }))
                .toggleStyle(.switch)

            HStack {
                Button("清除对话记录", role: .destructive) {
                    showClearChatConfirm = true
                }
                .buttonStyle(SecondaryActionButton())
                Spacer()
            }
        }
        .card(padding: 20)
        .confirmationDialog("确定清除全部对话记录吗？", isPresented: $showClearChatConfirm, titleVisibility: .visible) {
            Button("清除", role: .destructive) {
                appState.clearChatHistory()
            }
            Button("取消", role: .cancel) {}
        }
    }

    private var bankSection: some View {        VStack(alignment: .leading, spacing: 14) {
            Text("题库总览").font(Theme.sectionTitle)

            VStack(spacing: 0) {
                ForEach(Array(Level.allCases.enumerated()), id: \.element) { offset, l in
                    if offset > 0 {
                        Divider().overlay(Theme.separator)
                    }
                    HStack {
                        Text(l.name).font(Theme.body)
                        Spacer()
                        Text("\(appState.count(for: l)) 题")
                            .font(Theme.font(14, .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12)
                }
            }
        }
        .card(padding: 20)
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield")
                .foregroundStyle(Theme.success)
            Text("题库和成绩都只保存在这台电脑上，不会上传到任何服务器。")
                .font(Theme.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }

    private func labeledField<Content: View>(
        _ title: String,
        hint: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(title).font(Theme.label)
                Text(hint).font(Theme.caption).foregroundStyle(.secondary)
            }
            content()
        }
    }

    private func load() {
        baseURL = appState.aiConfig.baseURL
        apiKey = appState.aiConfig.apiKey
        model = appState.aiConfig.model
    }

    private func save() {
        let config = AIConfig(baseURL: baseURL, apiKey: apiKey, model: model)
        appState.saveAIConfig(config)
        saved = true
    }
}
