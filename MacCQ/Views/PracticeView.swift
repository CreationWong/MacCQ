//
//  PracticeView.swift
//  MacCQ
//
//  Created by CreationWong on 2026/9/2.
//

import SwiftUI

struct PracticeView: View {
    let level: Level
    @Environment(AppState.self) private var appState

    @State private var questions: [ExamQuestion] = []
    @State private var index = 0
    @State private var selection: Set<Int> = []
    @State private var revealed = false
    @State private var jumpText = ""

    var body: some View {
        Group {
            if questions.isEmpty {
                EmptyBankView(level: level, hint: "请先在【导入题库】中导入该级别的题库")
            } else {
                VStack(spacing: 0) {
                    header
                    Divider()
                    ScrollView {
                        QuestionCardView(question: questions[index], revealed: revealed, selection: $selection)
                            .frame(maxWidth: 720)
                            .frame(maxWidth: .infinity)
                            .padding(24)
                    }
                    controls
                }
            }
        }
        .navigationTitle("练习 · \(level.name)")
        .onAppear { load() }
        .frame(minWidth: 540, minHeight: 480)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("第 \(index + 1) / \(questions.count) 题")
                .font(.system(.headline, design: .rounded))
            jumpField
            Spacer()
            if revealed {
                let ok = ExamEngine.isCorrect(answer: selection, for: questions[index])
                Label(ok ? "回答正确" : "回答有误", systemImage: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(ok ? .green : .red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassPill(cornerRadius: 20)
            }
        }
        .padding()
    }

    private var jumpField: some View {
        HStack(spacing: 4) {
            TextField("跳转到…", text: $jumpText)
                .textFieldStyle(.plain)
                .font(.system(.caption, design: .rounded))
                .frame(width: 56)
                .multilineTextAlignment(.center)
                .onSubmit { jumpTo() }
            Button {
                jumpTo()
            } label: {
                Image(systemName: "arrow.right")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .glassPill(cornerRadius: 8)
    }

    private func jumpTo() {
        guard let n = Int(jumpText), n >= 1, n <= questions.count else { return }
        index = n - 1
        selection = []
        revealed = false
        jumpText = ""
    }

    private var controls: some View {
        HStack {
            Button(role: .none) { step(-1) } label: { Label("上一题", systemImage: "chevron.left") }
                .buttonStyle(.bordered)
                .disabled(index == 0)
            Spacer()
            if !revealed {
                Button {
                    revealed = true
                } label: {
                    Label("查看答案", systemImage: "eye")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(MacDesign.accentTint)
            } else {
                Button {
                    step(1)
                } label: {
                    Label("下一题", systemImage: "chevron.right")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(MacDesign.accentTint)
            }
            Spacer()
            Button(role: .none) { step(1) } label: { Label("下一题", systemImage: "chevron.right") }
                .buttonStyle(.bordered)
                .disabled(index == questions.count - 1 || revealed)
                .opacity(revealed ? 0 : 1)
        }
        .padding()
    }

    private func step(_ delta: Int) {
        let next = min(max(0, index + delta), max(0, questions.count - 1))
        guard next != index else { return }
        index = next
        selection = []
        revealed = false
    }

    private func load() {
        let bank = DatabaseManager.shared.loadQuestions(level: level.rawValue)
        questions = ExamEngine.buildExam(bank: bank, count: bank.count)
        // Reset navigation state whenever the bank is loaded, including an
        // empty bank, so no stale answer or index survives a level switch.
        selection = []
        revealed = false
        index = 0
    }
}
