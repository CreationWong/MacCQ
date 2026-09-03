//
//  SettingsView.swift
//  MacCQ
//
//  Created by CreationWong on 2026/9/2.
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var model = ""
    @State private var saved = false

    var body: some View {
        Form {
            Section {
                TextField("接口地址（Base URL）", text: $baseURL,
                          prompt: Text("https://api.example.com/v1"))
                SecureField("API Key", text: $apiKey)
                TextField("模型名称", text: $model, prompt: Text("如 pi"))
            } header: {
                Text("AI 答疑接口（OpenAI 兼容）")
            } footer: {
                Text("仅需配置端点、Key 与模型名称即可启用 AI 答疑。")
            }

            Section {
                HStack {
                    Spacer()
                    Button("保存") { save() }
                        .buttonStyle(.borderedProminent)
                        .disabled(baseURL.isEmpty || apiKey.isEmpty || model.isEmpty)
                    Text(saved ? "已保存" : "")
                        .foregroundStyle(.green)
                }
            }

            Section {
                ForEach(Level.allCases) { l in
                    HStack {
                        Text("\(l.name)类")
                        Spacer()
                        Text("\(appState.count(for: l)) 题")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("题库总览")
            }

            Section {
                Label("数据库：Application Support/MacCQ/maccq.sqlite", systemImage: "externaldrive")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 540, minHeight: 400)
        .scrollContentBackground(.hidden)
        .navigationTitle("设置")
        .onAppear { load() }
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
