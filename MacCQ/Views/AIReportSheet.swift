//
//  AIReportSheet.swift
//  MacCQ
//

import SwiftUI

/// 通用的 AI 分析结果弹窗：进入时自动生成，支持未配置、加载、失败与正文状态。
struct AIReportSheet: View {
    let title: String
    let systemPrompt: String
    let userPrompt: String

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Theme.accent)
                Text(title).font(Theme.cardTitle)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider().overlay(Theme.separator)

            content

            Divider().overlay(Theme.separator)

            HStack {
                Spacer()
                Button("关闭") { dismiss() }
                    .buttonStyle(SecondaryActionButton())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 580, height: 520)
        .background(Theme.canvas)
        .onAppear { run() }
    }

    @ViewBuilder
    private var content: some View {
        if !appState.aiConfig.isConfigured {
            EmptyStateView(
                icon: "sparkles",
                title: "智能分析尚未启用",
                message: "请先到左侧「设置」中填写服务信息，再使用 AI 分析。")
        } else if isLoading {
            VStack(spacing: 12) {
                ProgressView()
                Text("正在生成分析…")
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error {
            EmptyStateView(icon: "exclamationmark.triangle", title: "分析失败", message: error)
        } else {
            ScrollView {
                MarkdownView(text: text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
        }
    }

    private func run() {
        guard appState.aiConfig.isConfigured else { return }
        isLoading = true
        Task {
            do {
                text = try await AIService.shared.send(config: appState.aiConfig, messages: [
                    ChatMessage(role: "system", content: systemPrompt),
                    ChatMessage(role: "user", content: userPrompt),
                ])
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}
