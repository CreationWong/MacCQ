//
//  AIView.swift
//  MacCQ
//
//  Created by CreationWong on 2026/9/2.
//

import SwiftUI

struct AIView: View {
    @Environment(AppState.self) private var appState
    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var referenced: Question?
    @State private var bankByLevel: [String: [Question]] = [:]

    var body: some View {
        VStack(spacing: 0) {
            if !appState.aiConfig.isConfigured {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                    Text("尚未配置 AI 接口，请先到【设置】填写端点、Key 与模型。")
                }
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.orange.opacity(0.12))
            }

            if messages.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 42))
                        .foregroundStyle(.secondary)
                    Text("向 AI 提问，或引用题库中的题目")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(messages.enumerated()), id: \.offset) { _, m in
                                bubble(m)
                            }
                            if isLoading {
                                HStack { ProgressView(); Text("正在思考…").font(.caption) }
                                    .padding()
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) {
                        if let last = messages.indices.last {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            inputBar
        }
        .navigationTitle("AI 答疑")
        .onAppear { loadBank() }
    }

    private func bubble(_ m: ChatMessage) -> some View {
        HStack {
            if m.role == "user" { Spacer(minLength: 60) }
            Text(m.content)
                .font(.system(.body, design: .rounded))
                .textSelection(.enabled)
                .padding(12)
                .background(m.role == "user" ? Color.blue.opacity(0.2) : Color.white.opacity(0.15))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
                .frame(maxWidth: .infinity, alignment: m.role == "user" ? .trailing : .leading)
            if m.role != "user" { Spacer(minLength: 60) }
        }
    }

    private var inputBar: some View {
        VStack(spacing: 12) {
            if let ref = referenced {
                HStack {
                    Image(systemName: "quote.bubble")
                    Text("已引用第 \(ref.bankOrder) 题（\(ref.type.label)）")
                        .font(.system(.caption, design: .rounded))
                        .lineLimit(1)
                    Spacer()
                    Button { referenced = nil } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .glassPill(cornerRadius: 10)
            }

            HStack {
                TextField("输入你的问题（可引用题目）…", text: $input, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .rounded))
                    .lineLimit(1...6)
                    .onSubmit { if !isLoading { send() } }
                    .padding(.horizontal, 8)

                Button {
                    send()
                } label: {
                    if isLoading {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(MacDesign.accentTint)
                .disabled(isLoading || input.trimmingCharacters(in: .whitespaces).isEmpty)

                Menu {
                    ForEach(Level.allCases) { l in
                        Menu(l.name) {
                            let qs = bankByLevel[l.rawValue] ?? []
                            if qs.isEmpty {
                                Text("暂无题目")
                            } else {
                                ForEach(qs, id: \.id) { q in
                                    Button("第 \(q.bankOrder) 题：\(q.stem.prefix(12))…") {
                                        referenced = q
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    Label("引用", systemImage: "quote.bubble")
                }
                .menuStyle(.button)
                .fixedSize()
                .disabled(isLoading)
            }
            .padding(10)
            .glassPill(cornerRadius: 14)
            .padding()
        }
    }

    private func send() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        var content = trimmed
        if let ref = referenced {
            let opts = ref.options.enumerated()
                .map { "\(ExamEngine.optionLetter($0.offset))、\($0.element)" }
                .joined(separator: "\n")
            content = "【题目 \(ref.type.label)】\(ref.stem)\n\(opts)\n\n我的问题：\(trimmed)"
        }
        guard !content.isEmpty else { return }
        messages.append(ChatMessage(role: "user", content: content))
        input = ""
        referenced = nil
        errorMessage = nil
        isLoading = true

        let system = ChatMessage(role: "system", content: "你是考试辅导助手。请用简体中文、条理清晰地解答题库疑问：解释知识点、给出依据，尽量简洁。")
        let payload = messages
        Task {
            do {
                let answer = try await AIService.shared.send(config: appState.aiConfig, messages: [system] + payload)
                messages.append(ChatMessage(role: "assistant", content: answer))
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func loadBank() {
        let all = DatabaseManager.shared.loadAllQuestions()
        var grouped: [String: [Question]] = [:]
        for q in all { grouped[q.level, default: []].append(q) }
        bankByLevel = grouped
    }
}
