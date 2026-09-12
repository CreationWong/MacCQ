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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                aiSection
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

    private var bankSection: some View {
        VStack(alignment: .leading, spacing: 14) {
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
