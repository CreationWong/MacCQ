//
//  ExamHostView.swift
//  MacCQ
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
        .pageBackground()
        .navigationTitle("模拟考试 · \(level.name)")
        .frame(minWidth: 620, minHeight: 560)
        .onReceive(timer) { _ in onTick() }
        .confirmationDialog("确定要交卷吗？", isPresented: $showSubmitConfirm, titleVisibility: .visible) {
            Button("确定交卷") { submit() }
            Button("继续答题", role: .cancel) {}
        } message: {
            Text(submitMessage)
        }
    }

    // MARK: - 开始页

    private var setupView: some View {
        ScrollView {
            VStack(spacing: 26) {
                VStack(spacing: 8) {
                    Tag(text: level.shortName)
                    Text("模拟考试")
                        .font(Theme.pageTitle)
                    Text("请在规定时间内完成答题，交卷后可查看成绩与错题。")
                        .font(Theme.body)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 0) {
                    ruleRow("题目数量", "\(level.questionCount) 题")
                    Divider().overlay(Theme.separator)
                    ruleRow("考试时长", "\(level.timeMinutes) 分钟")
                    Divider().overlay(Theme.separator)
                    ruleRow("合格标准", "答对 \(level.passCount) 题及以上")
                    Divider().overlay(Theme.separator)
                    ruleRow("当前题库", "\(appState.count(for: level)) 题")
                }
                .card(padding: 0)
                .frame(maxWidth: 380)

                Button {
                    startExam()
                } label: {
                    Text(appState.count(for: level) == 0 ? "请先导入题库" : "开始考试")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButton())
                .frame(maxWidth: 320)
                .disabled(appState.count(for: level) == 0)

                Text("题目按题库顺序抽取，选项顺序每次随机打乱。")
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(40)
        }
    }

    private func ruleRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(Theme.font(14, .semibold))
        }
        .font(Theme.body)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - 答题页

    private var runningView: some View {
        VStack(spacing: 0) {
            examHeader
            Divider().overlay(Theme.separator)
            if !paper.isEmpty {
                ScrollView {
                    QuestionCardView(question: paper[currentIndex], revealed: false, selection: binding(for: currentIndex))
                        .frame(maxWidth: 720)
                        .frame(maxWidth: .infinity)
                        .padding(28)
                }
            }
            Divider().overlay(Theme.separator)
            examFooter
        }
    }

    private var examHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("第 \(currentIndex + 1) / \(paper.count) 题")
                    .font(Theme.cardTitle)
                if paper.indices.contains(currentIndex) {
                    Text(paper[currentIndex].type.label)
                        .font(Theme.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "timer")
                Text(timeText(remaining))
                    .font(Theme.mono)
            }
            .foregroundStyle(remaining <= 60 ? Theme.danger : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                remaining <= 60 ? Theme.danger.opacity(0.10) : Theme.surfaceMuted,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Button("交卷") { showSubmitConfirm = true }
                .buttonStyle(PrimaryActionButton())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private var examFooter: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(paper.indices, id: \.self) { i in
                        let answered = (answers[i]?.isEmpty == false)
                        Button {
                            currentIndex = i
                        } label: {
                            Text("\(i + 1)")
                                .font(Theme.font(12, .medium))
                                .frame(width: 30, height: 30)
                                .background(
                                    cellBackground(answered: answered, current: i == currentIndex),
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .foregroundStyle(cellForeground(answered: answered, current: i == currentIndex))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)
            }
            HStack {
                Button {
                    move(-1)
                } label: {
                    Label("上一题", systemImage: "chevron.left")
                }
                .buttonStyle(SecondaryActionButton())
                .disabled(currentIndex == 0)

                Spacer()

                Button {
                    move(1)
                } label: {
                    Label("下一题", systemImage: "chevron.right")
                }
                .buttonStyle(SecondaryActionButton())
                .disabled(currentIndex == paper.count - 1)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 14)
        }
    }

    private func cellBackground(answered: Bool, current: Bool) -> Color {
        if current { return Theme.accent }
        if answered { return Theme.success.opacity(0.14) }
        return Theme.surfaceMuted
    }

    private func cellForeground(answered: Bool, current: Bool) -> Color {
        if current { return .white }
        if answered { return Theme.success }
        return .secondary
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
        for i in wrong {
            appState.addWrongQuestion(paper[i].id)
        }
        let weakTopics = StudyAnalyzer.analyze(paper: paper, answers: answers).weakTopics.map(\.title)
        appState.recordFinished(level: level, mode: "exam", total: paper.count,
                                correct: correct, duration: level.timeSeconds - max(0, remaining),
                                weakTopics: weakTopics)
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
        return unanswered > 0 ? "还有 \(unanswered) 题未作答。" : "所有题目都已作答。"
    }
}
