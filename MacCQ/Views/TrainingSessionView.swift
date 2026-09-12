//
//  TrainingSessionView.swift
//  MacCQ
//

import SwiftUI
import Combine

/// AI 工具创建的训练会话：讲解（PPT）→ 测验（带解析）→ 限时考试（真题）→ 小结。
struct TrainingSessionView: View {
    let artifacts: [ChatArtifact]
    let onClose: () -> Void

    @Environment(AppState.self) private var appState

    private enum Stage: Int, CaseIterable {
        case lesson, quiz, exam, summary

        var title: String {
            switch self {
            case .lesson: return "讲解"
            case .quiz: return "测验"
            case .exam: return "考试"
            case .summary: return "小结"
            }
        }
    }

    private let lesson: LessonArtifact?
    private let quiz: QuizArtifact?
    private let exam: ExamArtifact?

    @State private var stage: Stage
    @State private var slideIndex = 0

    // 测验
    @State private var quizIndex = 0
    @State private var quizSelection: Set<Int> = []
    @State private var quizRevealed = false

    // 考试
    @State private var examIndex = 0
    @State private var examAnswers: [Int: Set<Int>] = [:]
    @State private var examRemaining = 0
    @State private var examSubmitted = false
    @State private var examResult: (correct: Int, wrong: [Int])?
    @State private var showSubmitConfirm = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // 汇总
    @State private var answered: [ExamQuestion] = []
    @State private var wrong: [ExamQuestion] = []
    @State private var errataQuestion: ExamQuestion?

    init(artifacts: [ChatArtifact], onClose: @escaping () -> Void) {
        self.artifacts = artifacts
        self.onClose = onClose

        let lesson = artifacts.compactMap { artifact -> LessonArtifact? in
            if case .lesson(let a) = artifact { return a } else { return nil }
        }.first
        let quiz = artifacts.compactMap { artifact -> QuizArtifact? in
            if case .quiz(let a) = artifact { return a } else { return nil }
        }.first
        let exam = artifacts.compactMap { artifact -> ExamArtifact? in
            if case .exam(let a) = artifact { return a } else { return nil }
        }.first

        self.lesson = lesson
        self.quiz = quiz
        self.exam = exam

        let initial: Stage
        if lesson != nil {
            initial = .lesson
        } else if quiz != nil {
            initial = .quiz
        } else if exam != nil {
            initial = .exam
        } else {
            initial = .summary
        }
        _stage = State(initialValue: initial)
        _examRemaining = State(initialValue: (exam?.minutes ?? 0) * 60)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.separator)
            content
        }
        .pageBackground()
        .sheet(item: $errataQuestion) { question in
            ErrataSheet(question: question)
        }
        .onReceive(timer) { _ in onTick() }
        .confirmationDialog("确定要交卷吗？", isPresented: $showSubmitConfirm, titleVisibility: .visible) {
            Button("确定交卷") { submitExam() }
            Button("继续答题", role: .cancel) {}
        } message: {
            Text(examSubmitMessage)
        }
    }

    // MARK: - 顶部

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(titleText).font(Theme.cardTitle)
                    Text(subtitleText).font(Theme.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    onClose()
                } label: {
                    Label("返回对话", systemImage: "bubble.left.and.bubble.right")
                }
                .buttonStyle(SecondaryActionButton())
            }

            HStack(spacing: 8) {
                ForEach(availableStages, id: \.self) { s in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(s == stage ? Theme.accent : Theme.border)
                            .frame(width: 6, height: 6)
                        Text(s.title)
                            .font(Theme.caption)
                            .foregroundStyle(s == stage ? Color.primary : .secondary)
                    }
                    if s != availableStages.last {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private var titleText: String {
        lesson?.title ?? quiz?.title ?? exam?.title ?? "专项训练"
    }

    private var subtitleText: String {
        let level = lesson?.level ?? quiz?.level ?? exam?.level ?? .a
        let topic = lesson?.topic ?? ""
        return topic.isEmpty ? level.shortName : "\(topic) · \(level.shortName)"
    }

    private var availableStages: [Stage] {
        var stages: [Stage] = []
        if lesson != nil { stages.append(.lesson) }
        if quiz != nil { stages.append(.quiz) }
        if exam != nil { stages.append(.exam) }
        stages.append(.summary)
        return stages
    }

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .lesson: lessonView
        case .quiz: quizView
        case .exam: examView
        case .summary: summaryView
        }
    }

    // MARK: - 讲解

    private var lessonView: some View {
        Group {
            if let lesson, slideIndex < lesson.slides.count {
                VStack(spacing: 0) {
                    ScrollView {
                        slideCard(lesson.slides[slideIndex], total: lesson.slides.count)
                            .frame(maxWidth: 720)
                            .frame(maxWidth: .infinity)
                            .padding(28)
                    }
                    Divider().overlay(Theme.separator)
                    HStack(spacing: 12) {
                        Button {
                            slideIndex = max(0, slideIndex - 1)
                        } label: {
                            Label("上一页", systemImage: "chevron.left")
                        }
                        .buttonStyle(SecondaryActionButton())
                        .disabled(slideIndex == 0)

                        Spacer()

                        Text("\(slideIndex + 1) / \(lesson.slides.count)")
                            .font(Theme.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        if slideIndex < lesson.slides.count - 1 {
                            Button {
                                slideIndex += 1
                            } label: {
                                Label("下一页", systemImage: "chevron.right")
                            }
                            .buttonStyle(PrimaryActionButton())
                        } else {
                            Button {
                                advanceFromLesson()
                            } label: {
                                Label("开始练习", systemImage: "play.fill")
                            }
                            .buttonStyle(PrimaryActionButton())
                        }

                        Button("跳过讲解") { advanceFromLesson() }
                            .buttonStyle(.plain)
                            .font(Theme.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                }
            }
        }
    }

    private func slideCard(_ slide: LessonSlide, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("讲解 · 第 \(slideIndex + 1) / \(total) 页")
                .font(Theme.caption)
                .foregroundStyle(.secondary)

            Text(slide.title)
                .font(Theme.font(26, .bold))
                .fixedSize(horizontal: false, vertical: true)

            if !slide.points.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(slide.points, id: \.self) { point in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(Theme.accent)
                                .frame(width: 6, height: 6)
                                .padding(.top, 7)
                            Text(point)
                                .font(Theme.font(16))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            if let example = slide.example, !example.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("例子 / 记忆技巧", systemImage: "lightbulb")
                        .font(Theme.label)
                        .foregroundStyle(Theme.accent)
                    Text(example)
                        .font(Theme.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 32)
    }

    private func advanceFromLesson() {
        if quiz != nil {
            stage = .quiz
        } else if exam != nil {
            stage = .exam
        } else {
            stage = .summary
        }
    }

    // MARK: - 测验

    private var quizView: some View {
        Group {
            if let quiz, quizIndex < quiz.questions.count {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 14) {
                            QuestionCardView(
                                question: quiz.questions[quizIndex],
                                revealed: quizRevealed,
                                selection: $quizSelection)
                            if quizRevealed,
                               let explanation = quiz.questions[quizIndex].explanation,
                               !explanation.isEmpty {
                                explanationCard(explanation)
                            }
                        }
                        .frame(maxWidth: 720)
                        .frame(maxWidth: .infinity)
                        .padding(28)
                    }
                    Divider().overlay(Theme.separator)
                    practiceControls(
                        index: quizIndex,
                        total: quiz.questions.count,
                        revealed: quizRevealed,
                        nextTitle: exam == nil ? "进入小结" : "进入考试",
                        onPrev: { quizStep(-1) },
                        onReveal: {
                            quizRevealed = true
                            record(quiz.questions[quizIndex], selection: quizSelection)
                        },
                        onNext: { stage = exam == nil ? .summary : .exam })
                }
            }
        }
    }

    private func quizStep(_ delta: Int) {
        guard let quiz else { return }
        let next = min(max(0, quizIndex + delta), max(0, quiz.questions.count - 1))
        guard next != quizIndex else { return }
        quizIndex = next
        quizSelection = []
        quizRevealed = false
    }

    // MARK: - 考试

    @ViewBuilder
    private var examView: some View {
        if let exam {
            if examSubmitted, let result = examResult {
                examResultView(exam: exam, result: result)
            } else {
                VStack(spacing: 0) {
                    examHeader(exam: exam)
                    Divider().overlay(Theme.separator)
                    if examIndex < exam.questions.count {
                        ScrollView {
                            QuestionCardView(
                                question: exam.questions[examIndex],
                                revealed: false,
                                selection: examBinding(examIndex))
                                .frame(maxWidth: 720)
                                .frame(maxWidth: .infinity)
                                .padding(28)
                        }
                    }
                    Divider().overlay(Theme.separator)
                    examFooter(exam: exam)
                }
            }
        }
    }

    private func examHeader(exam: ExamArtifact) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("第 \(examIndex + 1) / \(exam.questions.count) 题")
                    .font(Theme.cardTitle)
                Text("考试 · \(exam.level.shortName)")
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "timer")
                Text(timeText(examRemaining)).font(Theme.mono)
            }
            .foregroundStyle(examRemaining <= 60 ? Theme.danger : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                examRemaining <= 60 ? Theme.danger.opacity(0.10) : Theme.surfaceMuted,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Button("交卷") { showSubmitConfirm = true }
                .buttonStyle(PrimaryActionButton())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private func examFooter(exam: ExamArtifact) -> some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(exam.questions.indices, id: \.self) { i in
                        let answered = (examAnswers[i]?.isEmpty == false)
                        Button {
                            examIndex = i
                        } label: {
                            Text("\(i + 1)")
                                .font(Theme.font(12, .medium))
                                .frame(width: 30, height: 30)
                                .background(
                                    cellBackground(answered: answered, current: i == examIndex),
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .foregroundStyle(cellForeground(answered: answered, current: i == examIndex))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)
            }
            HStack {
                Button {
                    examIndex = max(0, examIndex - 1)
                } label: {
                    Label("上一题", systemImage: "chevron.left")
                }
                .buttonStyle(SecondaryActionButton())
                .disabled(examIndex == 0)

                Spacer()

                Button {
                    examIndex = min(exam.questions.count - 1, examIndex + 1)
                } label: {
                    Label("下一题", systemImage: "chevron.right")
                }
                .buttonStyle(SecondaryActionButton())
                .disabled(examIndex == exam.questions.count - 1)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 14)
        }
    }

    private func examResultView(exam: ExamArtifact, result: (correct: Int, wrong: [Int])) -> some View {
        let passed = exam.level.passed(correctCount: result.correct)
        let accuracy = exam.questions.isEmpty ? 0 : Double(result.correct) / Double(exam.questions.count)
        return ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 10) {
                    Image(systemName: passed ? "checkmark.seal.fill" : "xmark.seal.fill")
                        .font(.system(size: 46))
                        .foregroundStyle(passed ? Theme.success : Theme.danger)
                    Text(passed ? "考试合格" : "考试未合格").font(Theme.pageTitle)
                    Text("答对 \(result.correct) / \(exam.questions.count) 题，用时 \(timeText(exam.minutes * 60 - max(0, examRemaining)))。")
                        .font(Theme.body)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 0) {
                    statItem("答对", "\(result.correct)")
                    Divider().frame(height: 32).overlay(Theme.separator)
                    statItem("答错", "\(result.wrong.count)")
                    Divider().frame(height: 32).overlay(Theme.separator)
                    statItem("正确率", String(format: "%.0f%%", accuracy * 100))
                }
                .card(padding: 18)
                .frame(maxWidth: 520)

                if !result.wrong.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("错题回顾").font(Theme.sectionTitle)
                        VStack(spacing: 0) {
                            ForEach(Array(result.wrong.enumerated()), id: \.element) { offset, i in
                                if offset > 0 { Divider().overlay(Theme.separator) }
                                let q = exam.questions[i]
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("\(i + 1)、\(q.stem)")
                                        .font(Theme.font(14, .medium))
                                        .fixedSize(horizontal: false, vertical: true)
                                    HStack(spacing: 16) {
                                        Label("你的答案：\(letters(examAnswers[i] ?? []))", systemImage: "xmark")
                                            .foregroundStyle(Theme.danger)
                                        Label("正确答案：\(letters(Set(q.correctIndices)))", systemImage: "checkmark")
                                            .foregroundStyle(Theme.success)
                                    }
                                    .font(Theme.caption)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 10)
                            }
                        }
                    }
                    .card(padding: 20)
                    .frame(maxWidth: 640)
                }

                Button("进入小结") { stage = .summary }
                    .buttonStyle(PrimaryActionButton())
            }
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
            .padding(32)
        }
    }

    private func submitExam() {
        guard let exam else { return }
        let (correct, wrongIndices) = ExamEngine.gradePaper(exam: exam.questions, answers: examAnswers)
        examResult = (correct, wrongIndices)
        for (i, q) in exam.questions.enumerated() {
            let answer = examAnswers[i] ?? []
            if !answer.isEmpty {
                record(q, selection: answer)
            }
            if !ExamEngine.isCorrect(answer: answer, for: q) {
                appState.addWrongQuestion(q.id)
            }
        }
        let weak = StudyAnalyzer.analyze(paper: exam.questions, answers: examAnswers).weakTopics.map(\.title)
        appState.recordFinished(
            level: exam.level, mode: "exam", total: exam.questions.count,
            correct: correct, duration: exam.minutes * 60 - max(0, examRemaining),
            weakTopics: weak)
        examSubmitted = true
    }

    private func onTick() {
        guard stage == .exam, !examSubmitted, exam != nil else { return }
        examRemaining -= 1
        if examRemaining <= 0 {
            submitExam()
        }
    }

    private var examSubmitMessage: String {
        guard let exam else { return "确定交卷吗？" }
        let unanswered = exam.questions.indices.filter { examAnswers[$0]?.isEmpty ?? true }.count
        return unanswered > 0 ? "还有 \(unanswered) 题未作答。" : "所有题目都已作答。"
    }

    private func examBinding(_ index: Int) -> Binding<Set<Int>> {
        Binding(
            get: { examAnswers[index] ?? [] },
            set: { examAnswers[index] = $0 })
    }

    // MARK: - 小结

    private var summaryView: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 46))
                        .foregroundStyle(Theme.success)
                    Text("训练完成").font(Theme.pageTitle)
                    Text("共作答 \(answered.count) 题，答对 \(answered.count - wrong.count) 题。")
                        .font(Theme.body)
                        .foregroundStyle(.secondary)
                }

                StudyAnalysisCard(analysis: StudyAnalyzer.analyze(
                    wrongQuestions: wrong,
                    attempted: answered.count,
                    correct: answered.count - wrong.count))
                    .frame(maxWidth: 640)

                Button("返回对话") { onClose() }
                    .buttonStyle(PrimaryActionButton())
            }
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
            .padding(32)
        }
    }

    // MARK: - 通用

    private func practiceControls(
        index: Int,
        total: Int,
        revealed: Bool,
        nextTitle: String,
        onPrev: @escaping () -> Void,
        onReveal: @escaping () -> Void,
        onNext: @escaping () -> Void
    ) -> some View {
        HStack {
            Button {
                onPrev()
            } label: {
                Label("上一题", systemImage: "chevron.left")
            }
            .buttonStyle(SecondaryActionButton())
            .disabled(index == 0)

            Spacer()

            Text("第 \(index + 1) / \(total) 题")
                .font(Theme.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if !revealed {
                Button {
                    onReveal()
                } label: {
                    Label("查看答案", systemImage: "eye")
                }
                .buttonStyle(PrimaryActionButton())
            } else if index == total - 1 {
                Button {
                    onNext()
                } label: {
                    Label(nextTitle, systemImage: "arrow.right")
                }
                .buttonStyle(PrimaryActionButton())
            } else {
                Button {
                    onNext()
                } label: {
                    Label("下一题", systemImage: "chevron.right")
                }
                .buttonStyle(PrimaryActionButton())
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private func explanationCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("解析", systemImage: "lightbulb")
                .font(Theme.sectionTitle)
                .foregroundStyle(Theme.accent)
            Text(safeMarkdownText(text))
                .font(Theme.body)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 20)
    }

    private func statItem(_ label: String, _ value: String) -> some View {
        VStack(spacing: 5) {
            Text(value).font(Theme.font(19, .semibold))
            Text(label).font(Theme.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
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

    private func letters(_ set: Set<Int>) -> String {
        set.sorted().map { ExamEngine.optionLetter($0) }.joined(separator: " ")
    }

    private func timeText(_ seconds: Int) -> String {
        String(format: "%02d:%02d", max(0, seconds) / 60, max(0, seconds) % 60)
    }

    private func record(_ question: ExamQuestion, selection: Set<Int>) {
        if !answered.contains(where: { $0.id == question.id }) {
            answered.append(question)
        }
        if !ExamEngine.isCorrect(answer: selection, for: question),
           !wrong.contains(where: { $0.id == question.id }) {
            wrong.append(question)
        }
    }
}
