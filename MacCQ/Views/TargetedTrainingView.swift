//
//  TargetedTrainingView.swift
//  MacCQ
//

import SwiftUI

/// 一个可选择的训练主题
private struct TrainingTopic: Identifiable {
    let title: String
    let weakCount: Int
    var id: String { title }
}

/// AI 专项训练：针对薄弱知识点生成一套练习，像助教一样给出题目与解析。
struct TargetedTrainingView: View {
    var fixedLevel: Level?
    var initialTopics: [String]
    var showsCloseButton: Bool

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private enum Phase { case config, loading, session, finished }

    @State private var phase: Phase = .config
    @State private var level: Level
    @State private var selectedTopics: Set<String>
    @State private var questionCount = 10
    @State private var questions: [ExamQuestion] = []
    @State private var index = 0
    @State private var selection: Set<Int> = []
    @State private var revealed = false
    @State private var answered: [ExamQuestion] = []
    @State private var wrong: [ExamQuestion] = []
    @State private var errorMessage: String?
    @State private var generationID = UUID()

    init(fixedLevel: Level? = nil, initialTopics: [String] = [], showsCloseButton: Bool = false) {
        self.fixedLevel = fixedLevel
        self.initialTopics = initialTopics
        self.showsCloseButton = showsCloseButton
        _level = State(initialValue: fixedLevel ?? .a)
        _selectedTopics = State(initialValue: Set(initialTopics))
    }

    var body: some View {
        Group {
            switch phase {
            case .config: configView
            case .loading: loadingView
            case .session: sessionView
            case .finished: finishedView
            }
        }
        .pageBackground()
        .frame(minWidth: 560, minHeight: 560)
        .onAppear {
            if selectedTopics.isEmpty {
                selectedTopics = Set(weakTopicFocus.prefix(3).map(\.title))
            }
        }
    }

    // MARK: - 配置

    private var configView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                if !appState.aiConfig.isConfigured {
                    Label("智能答疑还没有启用，请先到「设置」填写服务信息。", systemImage: "info.circle")
                        .font(Theme.font(13))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("训练主题").font(Theme.sectionTitle)
                        Spacer()
                        Text(selectedTopics.isEmpty ? "未选择时覆盖核心考点" : "已选 \(selectedTopics.count) 个")
                            .font(Theme.caption)
                            .foregroundStyle(.secondary)
                    }
                    FlowLayout(spacing: 8) {
                        ForEach(topicOptions) { topic in
                            topicChip(topic)
                        }
                    }
                }
                .card(padding: 20)

                if fixedLevel == nil {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("考试级别").font(Theme.sectionTitle)
                        Picker("", selection: $level) {
                            ForEach(Level.allCases) { l in
                                Text(l.shortName).tag(l)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                    .card(padding: 20)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("题目数量").font(Theme.sectionTitle)
                    Picker("", selection: $questionCount) {
                        Text("5 题").tag(5)
                        Text("10 题").tag(10)
                        Text("15 题").tag(15)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .card(padding: 20)

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                        .font(Theme.font(13))
                        .foregroundStyle(Theme.danger)
                }

                Button {
                    generate()
                } label: {
                    Label("开始生成", systemImage: "wand.and.stars")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButton())
                .disabled(!appState.aiConfig.isConfigured)
            }
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(28)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("AI 专项训练")
                    .font(showsCloseButton ? Theme.cardTitle : Theme.pageTitle)
                Text("根据你的薄弱知识点生成一套针对性练习，交卷后可查看解析与学习分析。")
                    .font(Theme.body)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if showsCloseButton {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func topicChip(_ topic: TrainingTopic) -> some View {
        let isSelected = selectedTopics.contains(topic.title)
        return Button {
            if isSelected {
                selectedTopics.remove(topic.title)
            } else {
                selectedTopics.insert(topic.title)
            }
        } label: {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                }
                Text(topic.title)
                if topic.weakCount > 0 {
                    Text("薄弱")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            (isSelected ? Color.white.opacity(0.25) : Theme.warning.opacity(0.15)),
                            in: Capsule())
                }
            }
            .font(Theme.font(13, isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                isSelected ? Theme.accent : Theme.surfaceMuted,
                in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent : Theme.border, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 生成中

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("AI 正在针对薄弱点出题…")
                .font(Theme.body)
            Text("通常需要几秒钟，请稍候。")
                .font(Theme.caption)
                .foregroundStyle(.secondary)
            Button("取消") { cancelGeneration() }
                .buttonStyle(SecondaryActionButton())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 答题

    private var sessionView: some View {
        VStack(spacing: 0) {
            sessionHeader
            Divider().overlay(Theme.separator)
            ScrollView {
                VStack(spacing: 16) {
                    QuestionCardView(question: questions[index], revealed: revealed, selection: $selection)
                    if revealed, let explanation = questions[index].explanation, !explanation.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("解析", systemImage: "lightbulb")
                                .font(Theme.sectionTitle)
                                .foregroundStyle(Theme.accent)
                            Text(safeMarkdownText(explanation))
                                .font(Theme.body)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(padding: 20)
                    }
                }
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
                .padding(28)
            }
            Divider().overlay(Theme.separator)
            sessionControls
        }
    }

    private var sessionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("第 \(index + 1) / \(questions.count) 题")
                    .font(Theme.cardTitle)
                Text("专项训练 · \(level.shortName)")
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("退出训练") {
                phase = .config
            }
            .buttonStyle(SecondaryActionButton())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private var sessionControls: some View {
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
            } else if index == questions.count - 1 {
                Button {
                    phase = .finished
                } label: {
                    Label("完成训练", systemImage: "checkmark")
                }
                .buttonStyle(PrimaryActionButton())
            } else {
                Button {
                    step(1)
                } label: {
                    Label("下一题", systemImage: "chevron.right")
                }
                .buttonStyle(PrimaryActionButton())
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - 完成

    private var finishedView: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 46))
                        .foregroundStyle(Theme.success)
                    Text("训练完成")
                        .font(Theme.pageTitle)
                    Text("共作答 \(answered.count) 题，答对 \(answered.count - wrong.count) 题。")
                        .font(Theme.body)
                        .foregroundStyle(.secondary)
                }

                StudyAnalysisCard(analysis: StudyAnalyzer.analyze(
                    wrongQuestions: wrong,
                    attempted: answered.count,
                    correct: answered.count - wrong.count))
                    .frame(maxWidth: 640)

                HStack(spacing: 12) {
                    Button("再来一组") {
                        phase = .config
                    }
                    .buttonStyle(PrimaryActionButton())

                    if showsCloseButton {
                        Button("关闭") { dismiss() }
                            .buttonStyle(SecondaryActionButton())
                    }
                }
            }
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
            .padding(32)
        }
    }

    // MARK: - 逻辑

    private func generate() {
        guard appState.aiConfig.isConfigured else { return }
        let id = UUID()
        generationID = id
        phase = .loading
        errorMessage = nil

        let topics = selectedTopics.isEmpty
            ? Array(topicOptions.prefix(3).map(\.title))
            : Array(selectedTopics)
        let knowledge = topics.compactMap { title in
            KnowledgeBase.all.first { $0.title == title }
        }
        let prompt = AIQuestionGenerator.userPrompt(
            level: level, topics: topics, knowledge: knowledge, count: questionCount)

        Task {
            do {
                let response = try await AIService.shared.send(config: appState.aiConfig, messages: [
                    ChatMessage(role: "system", content: AIQuestionGenerator.systemPrompt),
                    ChatMessage(role: "user", content: prompt),
                ])
                guard generationID == id else { return }
                let generated = AIQuestionGenerator.parse(response, level: level)
                guard !generated.isEmpty else {
                    errorMessage = "AI 返回的题目无法解析，请重试一次。"
                    phase = .config
                    return
                }
                questions = generated
                index = 0
                selection = []
                revealed = false
                answered = []
                wrong = []
                phase = .session
            } catch {
                guard generationID == id else { return }
                errorMessage = error.localizedDescription
                phase = .config
            }
        }
    }

    private func cancelGeneration() {
        generationID = UUID()
        phase = .config
    }

    private func reveal() {
        revealed = true
        let question = questions[index]
        if !answered.contains(where: { $0.id == question.id }) {
            answered.append(question)
        }
        if !ExamEngine.isCorrect(answer: selection, for: question),
           !wrong.contains(where: { $0.id == question.id }) {
            wrong.append(question)
        }
    }

    private func step(_ delta: Int) {
        let next = min(max(0, index + delta), max(0, questions.count - 1))
        guard next != index else { return }
        index = next
        selection = []
        revealed = false
    }

    private var topicOptions: [TrainingTopic] {
        var result: [TrainingTopic] = weakTopicFocus.map {
            TrainingTopic(title: $0.title, weakCount: $0.count)
        }
        for entry in KnowledgeBase.all where !result.contains(where: { $0.title == entry.title }) {
            result.append(TrainingTopic(title: entry.title, weakCount: 0))
        }
        return result
    }

    /// 从考试记录中汇总薄弱主题
    private var weakTopicFocus: [TopicFocus] {
        var counts: [String: Int] = [:]
        for record in appState.records {
            for topic in record.weakTopics {
                counts[topic, default: 0] += 1
            }
        }
        for topic in initialTopics {
            counts[topic, default: 0] += 1
        }
        return counts
            .map { TopicFocus(title: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.title < $1.title }
    }
}
