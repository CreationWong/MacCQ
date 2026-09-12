//
//  PracticeSummarySheet.swift
//  MacCQ
//

import SwiftUI

/// 练习小结：可切换查看本地学习分析，或生成 AI 深度分析。
struct PracticeSummarySheet: View {
    let analysis: StudyAnalysis
    let level: Level
    let systemPrompt: String
    let userPrompt: String

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private enum Tab: String, CaseIterable, Identifiable {
        case local = "学习分析"
        case ai = "AI 分析"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .local
    @State private var aiText = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var showTraining = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Theme.accent)
                Text("练习小结").font(Theme.cardTitle)
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

            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            Divider().overlay(Theme.separator)

            ScrollView {
                Group {
                    if tab == .local {
                        StudyAnalysisCard(analysis: analysis)
                    } else {
                        aiContent
                    }
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().overlay(Theme.separator)

            HStack(spacing: 10) {
                if !analysis.weakTopics.isEmpty {
                    Button {
                        showTraining = true
                    } label: {
                        Label("专项训练", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(SecondaryActionButton())
                }
                Spacer()
                Button("关闭") { dismiss() }
                    .buttonStyle(SecondaryActionButton())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 580, height: 560)
        .background(Theme.canvas)
        .onChange(of: tab) {
            if tab == .ai { runAI() }
        }
        .sheet(isPresented: $showTraining) {
            TargetedTrainingView(
                fixedLevel: level,
                initialTopics: analysis.weakTopics.map(\.title),
                showsCloseButton: true)
        }
    }

    @ViewBuilder
    private var aiContent: some View {
        if !appState.aiConfig.isConfigured {
            EmptyStateView(
                icon: "sparkles",
                title: "智能分析尚未启用",
                message: "请先到左侧「设置」中填写服务信息，再使用 AI 分析。")
                .frame(minHeight: 320)
        } else if isLoading {
            VStack(spacing: 12) {
                ProgressView()
                Text("正在生成分析…")
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
        } else if let error {
            EmptyStateView(icon: "exclamationmark.triangle", title: "分析失败", message: error)
                .frame(minHeight: 320)
        } else {
            Text(safeMarkdownText(aiText))
                .font(Theme.body)
                .textSelection(.enabled)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func runAI() {
        guard aiText.isEmpty, !isLoading, appState.aiConfig.isConfigured else { return }
        isLoading = true
        error = nil
        Task {
            do {
                aiText = try await AIService.shared.send(config: appState.aiConfig, messages: [
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
