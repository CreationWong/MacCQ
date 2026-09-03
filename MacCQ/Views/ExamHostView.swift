//
//  ExamHostView.swift
//  MacCQ
//
//  Created by CreationWong on 2026/9/2.
//

import SwiftUI
import Combine

struct ExamHostView: View {
    let level: Level
    @Environment(AppState.self) private var appState

    private enum Phase { case setup, running, finished }
    @State private var phase: Phase = .setup
    @State private var paper: [ExamQuestion] = []
    @State private var answers: [Int: Set<Int>] = [:]
    @State private var currentIndex = 0
    @State private var remaining = 0
    @State private var result: (correct: Int, wrong: [Int])?
    @State private var showSubmitConfirm = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            switch phase {
            case .setup: setupView
            case .running: runningView
            case .finished:
                if let result {
                    ExamResultView(level: level, paper: paper, answers: answers,
                                   correct: result.correct, wrong: result.wrong,
                                   duration: level.timeSeconds - max(0, remaining)) {
                        startExam()
                    }
                }
            }
        }
        .navigationTitle("模拟考试 · \(level.name)")
        .frame(minWidth: 620, minHeight: 540)
        .onReceive(timer) { _ in onTick() }
        .confirmationDialog("交卷", isPresented: $showSubmitConfirm, titleVisibility: .visible) {
            Button("确定交卷") { submit() }
            Button("取消", role: .cancel) {}
        } message: {
            Text(submitMessage)
        }
    }

    // MARK: - 开始页

    private var setupView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 46))
                .foregroundStyle(.blue)
            Text(level.name)
                .font(.largeTitle.bold())
            VStack(spacing: 6) {
                ruleRow("题目数量", "\(level.questionCount) 题")
                ruleRow("考试时长", "\(level.timeMinutes) 分钟")
                ruleRow("及格标准", "答对 \(level.passCount) 题（含）以上")
                ruleRow("当前题库", "\(appState.count(for: level)) 题")
            }
            .padding(.vertical)
            .frame(maxWidth: 360)
            .glassCard(cornerRadius: 20)
            .padding(.horizontal, 24)

            Button {
                startExam()
            } label: {
                Text(appState.count(for: level) == 0 ? "题库为空，请先导入" : "开始考试")
                    .font(.system(.headline, design: .rounded))
                    .frame(minWidth: 180)
            }
            .buttonStyle(.borderedProminent)
            .tint(MacDesign.accentTint)
            .disabled(appState.count(for: level) == 0)

            Text("题目按题库顺序抽取，选项位置已打乱。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(40)
    }

    private func ruleRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
    }

    // MARK: - 答题页

    private var runningView: some View {
        VStack(spacing: 0) {
            examHeader
            Divider()
            if !paper.isEmpty {
                ScrollView {
                    QuestionCardView(question: paper[currentIndex], revealed: false, selection: binding(for: currentIndex))
                        .frame(maxWidth: 720)
                        .frame(maxWidth: .infinity)
                        .padding(24)
                }
            }
            examFooter
        }
    }

    private var examHeader: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("第 \(currentIndex + 1) / \(paper.count) 题")
                    .font(.headline)
                if paper.indices.contains(currentIndex) {
                    Text(paper[currentIndex].type.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Label(timeText(remaining), systemImage: "timer")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(remaining <= 60 ? .red : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .glassPill(cornerRadius: 20)
            Button("交卷") { showSubmitConfirm = true }
                .buttonStyle(.borderedProminent)
                .tint(MacDesign.accentTint)
        }
        .padding()
    }

    private var examFooter: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(paper.indices, id: \.self) { i in
                        let answered = (answers[i]?.isEmpty == false)
                        Button {
                            currentIndex = i
                        } label: {
                            Text("\(i + 1)")
                                .font(.system(.caption, design: .rounded, weight: .medium))
                                .frame(width: 30, height: 30)
                                .background(cellColor(answered: answered, current: i == currentIndex), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            HStack {
                Button { move(-1) } label: { Label("上一题", systemImage: "chevron.left") }
                    .disabled(currentIndex == 0)
                Spacer()
                Button { move(1) } label: { Label("下一题", systemImage: "chevron.right") }
                    .disabled(currentIndex == paper.count - 1)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    private func cellColor(answered: Bool, current: Bool) -> Color {
        if current { return MacDesign.accentTint.opacity(0.85) }
        if answered { return Color.green.opacity(0.65) }
        return MacDesign.subtleFill
    }

    private func binding(for index: Int) -> Binding<Set<Int>> {
        Binding(
            get: { answers[index] ?? [] },
            set: { answers[index] = $0 })
    }

    // MARK: - 逻辑

    private func startExam() {
        let bank = DatabaseManager.shared.loadQuestions(level: level.rawValue)
        guard !bank.isEmpty else { return }
        paper = ExamEngine.buildExam(bank: bank, count: level.questionCount)
        answers = [:]
        currentIndex = 0
        remaining = level.timeSeconds
        result = nil
        phase = .running
    }

    private func move(_ delta: Int) {
        let next = min(max(0, currentIndex + delta), max(0, paper.count - 1))
        currentIndex = next
    }

    private func submit() {
        let (correct, wrong) = ExamEngine.gradePaper(exam: paper, answers: answers)
        result = (correct, wrong)
        appState.recordFinished(level: level, mode: "exam", total: paper.count,
                                correct: correct, duration: level.timeSeconds - max(0, remaining))
        phase = .finished
    }

    private func onTick() {
        guard phase == .running else { return }
        remaining -= 1
        if remaining <= 0 { submit() }
    }

    private func timeText(_ s: Int) -> String {
        String(format: "%02d:%02d", s / 60, s % 60)
    }

    private var submitMessage: String {
        let unanswered = paper.indices.filter { answers[$0]?.isEmpty ?? true }.count
        return unanswered > 0 ? "还有 \(unanswered) 题未作答，确定交卷吗？" : "确定交卷吗？"
    }
}
