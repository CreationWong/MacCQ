//
//  PracticeView.swift
//  MacCQ
//

import SwiftUI

struct PracticeView: View {
    let level: Level
    @Environment(AppState.self) private var appState

    @State private var bank: [Question] = []
    @State private var questions: [ExamQuestion] = []
    @State private var index = 0
    @State private var selection: Set<Int> = []
    @State private var revealed = false
    @State private var jumpText = ""

    // 本次练习的作答记录，用于生成 AI 小结
    @State private var answeredQuestions: [ExamQuestion] = []
    @State private var wrongQuestions: [ExamQuestion] = []
    @State private var showExplain = false
    @State private var showSummary = false
    @State private var errataQuestion: ExamQuestion?

    var body: some View {
        Group {
            if questions.isEmpty {
                EmptyBankView(level: level, hint: "请先在左侧「导入题库」中导入该级别的题目。")
            } else {
                VStack(spacing: 0) {
                    header
                    Divider().overlay(Theme.separator)
                    ScrollView {
                        VStack(spacing: 14) {
                            QuestionCardView(
                                question: questions[index],
                                revealed: revealed,
                                selection: $selection,
                                isFavorite: appState.isFavorite(questions[index].id),
                                onToggleFavorite: { appState.toggleFavorite(questions[index].id) },
                                onErrata: { errataQuestion = questions[index] })
                            if let note = appState.note(for: questions[index].id), !note.isEmpty {
                                ErrataNoteView(note: note)
                            }
                        }
                        .frame(maxWidth: 720)
                        .frame(maxWidth: .infinity)
                        .padding(28)
                    }
                    Divider().overlay(Theme.separator)
                    controls
                }
            }
        }
        .pageBackground()
        .navigationTitle("练习 · \(level.name)")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    showExplain = true
                } label: {
                    Label("AI 讲解", systemImage: "sparkles")
                }
                .disabled(questions.isEmpty)

                Button {
                    showSummary = true
                } label: {
                    Label("练习小结", systemImage: "chart.bar.xaxis")
                }
                .disabled(wrongQuestions.isEmpty)
            }
        }
        .sheet(isPresented: $showExplain) {
            if !questions.isEmpty {
                let question = questions[index]
                AIReportSheet(
                    title: "AI 讲解本题",
                    systemPrompt: AITutor.tutorSystem,
                    userPrompt: AITutor.explainPrompt(
                        for: question,
                        knowledge: knowledge(for: question),
                        related: relatedQuestions(for: question),
                        note: appState.note(for: question.id)))
            }
        }
        .sheet(isPresented: $showSummary) {
            PracticeSummarySheet(
                analysis: StudyAnalyzer.analyze(
                    wrongQuestions: wrongQuestions,
                    attempted: answeredQuestions.count,
                    correct: answeredQuestions.count - wrongQuestions.count),
                level: level,
                systemPrompt: AITutor.analystSystem,
                userPrompt: AITutor.summaryPrompt(
                    wrong: wrongQuestions,
                    attempted: answeredQuestions.count,
                    correct: answeredQuestions.count - wrongQuestions.count,
                    knowledge: summaryKnowledge))
        }
        .sheet(item: $errataQuestion) { question in
            ErrataSheet(question: question)
        }
        .onAppear { load() }
        .frame(minWidth: 560, minHeight: 520)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("第 \(index + 1) / \(questions.count) 题")
                    .font(Theme.cardTitle)
                ProgressView(value: Double(index + 1), total: Double(questions.count))
                    .progressViewStyle(.linear)
                    .tint(Theme.accent)
                    .frame(width: 180)
            }

            Spacer()

            HStack(spacing: 6) {
                Text("跳转").font(Theme.caption).foregroundStyle(.secondary)
                TextField("", text: $jumpText)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .frame(width: 52)
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

            if revealed {
                let ok = ExamEngine.isCorrect(answer: selection, for: questions[index])
                Label(ok ? "回答正确" : "回答有误", systemImage: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(Theme.font(13, .semibold))
                    .foregroundStyle(ok ? Theme.success : Theme.danger)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        (ok ? Theme.success : Theme.danger).opacity(0.10),
                        in: Capsule())
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
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
            Button {
                step(-1)
            } label: {
                Label("上一题", systemImage: "chevron.left")
            }
            .buttonStyle(SecondaryActionButton())
            .disabled(index == 0)

            Spacer()

            if !revealed {
                Button {
                    reveal()
                } label: {
                    Label("查看答案", systemImage: "eye")
                }
                .buttonStyle(PrimaryActionButton())
            } else {
                Button {
                    step(1)
                } label: {
                    Label("下一题", systemImage: "chevron.right")
                }
                .buttonStyle(PrimaryActionButton())
                .disabled(index == questions.count - 1)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private func reveal() {
        revealed = true
        recordCurrentAnswer()
    }

    private func recordCurrentAnswer() {
        let question = questions[index]
        if !answeredQuestions.contains(where: { $0.id == question.id }) {
            answeredQuestions.append(question)
        }
        if !ExamEngine.isCorrect(answer: selection, for: question) {
            if !wrongQuestions.contains(where: { $0.id == question.id }) {
                wrongQuestions.append(question)
            }
            appState.addWrongQuestion(question.id)
        }
    }

    private func step(_ delta: Int) {
        let next = min(max(0, index + delta), max(0, questions.count - 1))
        guard next != index else { return }
        index = next
        selection = []
        revealed = false
    }

    private func knowledge(for question: ExamQuestion) -> [KnowledgeEntry] {
        KnowledgeBase.search(question.stem + " " + question.options.joined(separator: " "), limit: 3)
    }

    private func relatedQuestions(for question: ExamQuestion) -> [Question] {
        guard let base = bank.first(where: { $0.id == question.id }) else { return [] }
        return QuestionMatcher.related(to: base, bank: bank, limit: 4)
    }

    private var summaryKnowledge: [KnowledgeEntry] {
        var seen = Set<String>()
        var result: [KnowledgeEntry] = []
        for question in wrongQuestions {
            let entries = KnowledgeBase.search(question.stem + " " + question.options.joined(separator: " "), limit: 2)
            for entry in entries where seen.insert(entry.id).inserted {
                result.append(entry)
            }
        }
        return Array(result.prefix(6))
    }

    private func load() {
        bank = DatabaseManager.shared.loadQuestions(level: level.rawValue)
        questions = ExamEngine.buildExam(bank: bank, count: bank.count)
        // Reset navigation state whenever the bank is loaded, including an
        // empty bank, so no stale answer or index survives a level switch.
        selection = []
        revealed = false
        index = 0
        answeredQuestions = []
        wrongQuestions = []
    }
}
