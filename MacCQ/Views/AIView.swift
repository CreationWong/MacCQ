//
//  AIView.swift
//  MacCQ
//

import SwiftUI

/// 聊天中的一条消息，可能附带思考链/工具调用步骤，或 AI 通过工具创建的产物。
private struct TutorMessage: Identifiable {
    let id = UUID()
    let role: String
    let content: String
    var apiContent: String?
    var steps: [AgentStep] = []
    var artifacts: [ChatArtifact] = []

    init(role: String, content: String, apiContent: String? = nil,
         steps: [AgentStep] = [], artifacts: [ChatArtifact] = []) {
        self.role = role
        self.content = content
        self.apiContent = apiContent
        self.steps = steps
        self.artifacts = artifacts
    }

    init(record: ChatMessageRecord) {
        self.init(
            role: record.role,
            content: record.content,
            apiContent: record.apiContent,
            steps: record.steps,
            artifacts: record.artifacts.compactMap { $0.artifact })
    }

    var record: ChatMessageRecord {
        ChatMessageRecord(
            role: role,
            content: content,
            apiContent: apiContent,
            steps: steps,
            artifacts: artifacts.map { StoredArtifact($0) })
    }
}

/// 打开训练会话的请求
private struct TrainingSessionRequest: Identifiable {
    let id = UUID()
    let artifacts: [ChatArtifact]
}

struct AIView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case chat = "智能答疑"
        case training = "专项训练"
        var id: String { rawValue }
    }

    @Environment(AppState.self) private var appState
    @State private var mode: Mode = .chat

    // 答疑状态
    @State private var messages: [TutorMessage] = []
    @State private var input = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var referenced: [Question] = []
    @State private var allBank: [Question] = DatabaseManager.shared.loadAllQuestions()
    @State private var showReferPicker = false
    @State private var referSearch = ""
    @State private var referSelection: Set<Int64> = []

    // 由 AI 工具创建的训练
    @State private var session: TrainingSessionRequest?
    @State private var showClearChatConfirm = false

    // 对话记录
    @State private var sessions: [ChatSession] = []
    @State private var currentSessionId: Int64?
    @State private var showHistory = false

    var body: some View {
        ZStack {
            if let session {
                TrainingSessionView(artifacts: session.artifacts) {
                    self.session = nil
                }
            } else {
                normalContent
            }
        }
        .pageBackground()
        .navigationTitle("AI 助教")
        .toolbar(id: "ai-toolbar") {
            if appState.keepChatHistory {
                ToolbarItem(id: "history", placement: .primaryAction) {
                    Button {
                        showHistory = true
                    } label: {
                        Label("对话记录", systemImage: "clock.arrow.circlepath")
                    }
                    .help("对话记录")
                    .popover(isPresented: $showHistory, arrowEdge: .bottom) {
                        historyPopover
                    }
                }
            }
            if !messages.isEmpty {
                ToolbarItem(id: "clear-chat", placement: .primaryAction) {
                    Button(role: .destructive) {
                        showClearChatConfirm = true
                    } label: {
                        Label("清空对话", systemImage: "trash")
                    }
                    .help("清空当前对话")
                }
            }
        }
        .confirmationDialog("确定清空当前对话吗？", isPresented: $showClearChatConfirm, titleVisibility: .visible) {
            Button("清空", role: .destructive) {
                if let id = currentSessionId {
                    appState.clearChatSession(id)
                }
                messages = []
            }
            Button("取消", role: .cancel) {}
        }
        .onAppear {
            loadBank()
            loadHistory()
        }
    }

    // MARK: - 对话记录

    private var historyPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                newConversation()
            } label: {
                Label("新建对话", systemImage: "plus")
                    .font(Theme.font(13, .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            Divider().overlay(Theme.separator)

            if sessions.isEmpty {
                Text("暂无对话记录")
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(24)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(sessions) { item in
                            sessionRow(item)
                        }
                    }
                    .padding(6)
                }
            }
        }
        .frame(width: 300, height: 340)
    }

    private func sessionRow(_ item: ChatSession) -> some View {
        HStack(spacing: 8) {
            Button {
                selectSession(item)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: item.id == currentSessionId ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 13))
                        .foregroundStyle(item.id == currentSessionId ? Theme.accent : Color.secondary.opacity(0.5))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(Theme.font(13))
                            .lineLimit(1)
                        Text(item.updatedAt.formatted(.dateTime.month().day().hour().minute()))
                            .font(Theme.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                deleteSession(item)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("删除对话")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            item.id == currentSessionId ? Theme.accent.opacity(0.08) : Color.clear,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func newConversation() {
        messages = []
        showHistory = false
        guard appState.keepChatHistory else {
            currentSessionId = nil
            return
        }
        currentSessionId = appState.createChatSession(title: "新对话")
        sessions = appState.loadChatSessions()
    }

    private func selectSession(_ item: ChatSession) {
        currentSessionId = item.id
        messages = appState.loadChatRecords(sessionId: item.id).map(TutorMessage.init(record:))
        showHistory = false
    }

    private func deleteSession(_ item: ChatSession) {
        appState.deleteChatSession(item.id)
        sessions = appState.loadChatSessions()
        guard currentSessionId == item.id else { return }
        currentSessionId = sessions.first?.id
        if let id = currentSessionId {
            messages = appState.loadChatRecords(sessionId: id).map(TutorMessage.init(record:))
        } else {
            messages = []
        }
    }

    private var normalContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Picker("", selection: $mode) {
                    ForEach(Mode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 320)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider().overlay(Theme.separator)

            switch mode {
            case .chat: chatView
            case .training: TargetedTrainingView(showsCloseButton: false)
            }
        }
    }

    // MARK: - 答疑

    private var chatView: some View {
        VStack(spacing: 0) {
            if !appState.aiConfig.isConfigured {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                    Text("智能答疑还没有启用。请到左侧「设置」中填写服务信息。")
                }
                .font(Theme.font(13))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Theme.accent.opacity(0.08))
            }

            if messages.isEmpty {
                EmptyStateView(
                    icon: "bubble.left.and.bubble.right",
                    title: "有什么想问的？",
                    message: "直接提问即可。需要时我会查询你的题库、错题本、收藏和考试记录，并为你出讲解、测验和考试。")
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(messages) { m in
                                bubble(m).id(m.id)
                            }
                            if isLoading {
                                HStack(spacing: 8) {
                                    ProgressView().controlSize(.small)
                                    Text("正在思考…").font(Theme.caption).foregroundStyle(.secondary)
                                }
                                .padding(.leading, 4)
                            }
                        }
                        .frame(maxWidth: 760)
                        .frame(maxWidth: .infinity)
                        .padding(24)
                    }
                    .onChange(of: messages.count) {
                        if let last = messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.danger)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            inputBar
        }
    }

    private func bubble(_ m: TutorMessage) -> some View {
        let isUser = m.role == "user"
        return VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
            if isUser {
                HStack {
                    Spacer(minLength: 60)
                    Text(m.content)
                        .font(Theme.body)
                        .textSelection(.enabled)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .foregroundStyle(.white)
                        .background(
                            Theme.accent,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    if !m.steps.isEmpty {
                        agentSteps(m.steps)
                    }
                    if !m.content.isEmpty {
                        MarkdownView(text: m.content)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Theme.surface,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Theme.border, lineWidth: 1))
                    }
                    if !m.artifacts.isEmpty {
                        artifactButtons(m)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack { Spacer(minLength: 60) }
            }
        }
    }

    /// 展示 AI 的思考链与工具调用
    private func agentSteps(_ steps: [AgentStep]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "brain")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text("思考链与工具调用").font(Theme.font(12, .semibold)).foregroundStyle(.secondary)
            }

            ForEach(steps) { step in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: step.kind == .tool ? "wrench.and.screwdriver" : "ellipsis.bubble")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(step.kind == .tool ? Theme.accent : Color.secondary)
                        .frame(width: 16)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title)
                            .font(Theme.font(12, .semibold))
                            .foregroundStyle(step.kind == .tool ? Color.primary : .secondary)
                        if !step.detail.isEmpty {
                            Text(step.detail)
                                .font(Theme.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.surfaceMuted, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// AI 创建的讲解 / 测验 / 考试
    private func artifactButtons(_ m: TutorMessage) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(m.artifacts) { artifact in
                Button {
                    session = TrainingSessionRequest(artifacts: [artifact])
                } label: {
                    Label("\(artifact.kindTitle)：\(artifact.title)", systemImage: artifact.icon)
                }
                .buttonStyle(SecondaryActionButton())
            }

            if m.artifacts.count > 1 {
                Button {
                    session = TrainingSessionRequest(artifacts: m.artifacts)
                } label: {
                    Label("开始完整训练", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryActionButton())
            }
        }
    }

    private var inputBar: some View {
        VStack(spacing: 10) {
            if !referenced.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(referenced) { q in
                            HStack(spacing: 6) {
                                Image(systemName: "quote.bubble")
                                    .font(.system(size: 10))
                                Text("第 \(q.bankOrder) 题 · \(q.type.shortLabel)")
                                    .font(Theme.caption)
                                Button {
                                    referenced.removeAll { $0.id == q.id }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .buttonStyle(.plain)
                            }
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Theme.accent.opacity(0.08), in: Capsule())
                        }
                    }
                }
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField("输入你的问题…", text: $input, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(Theme.body)
                    .lineLimit(1...6)
                    .onSubmit { if !isLoading { send() } }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        Theme.surfaceMuted,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button {
                    referSearch = ""
                    referSelection = Set(referenced.map(\.id))
                    loadBank()
                    showReferPicker = true
                } label: {
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .background(Theme.surfaceMuted, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .disabled(isLoading)
                .popover(isPresented: $showReferPicker, arrowEdge: .bottom) {
                    QuestionPicker(
                        search: $referSearch,
                        questions: filteredQuestions,
                        selected: $referSelection,
                        onConfirm: confirmReferences)
                }

                Button {
                    send()
                } label: {
                    Group {
                        if isLoading {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 34, height: 34)
                    .background(
                        Theme.accent,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .opacity(canSend ? 1 : 0.45)
                .disabled(!canSend)
            }
        }
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Theme.canvas)
    }

    // MARK: - 逻辑

    private var canSend: Bool {
        !isLoading && !input.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func confirmReferences() {
        let selected = allBank
            .filter { referSelection.contains($0.id) }
            .sorted { ($0.level, $0.bankOrder) < ($1.level, $1.bankOrder) }
        referenced = selected
        showReferPicker = false
    }

    private func send() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let references = referenced
        // 不再强行关联题目/知识：由 AI 按需通过工具查询
        let enriched = AITutor.chatPrompt(
            query: trimmed, references: references, notes: appState.notes)

        let history = messages.map { ChatMessage(role: $0.role, content: $0.apiContent ?? $0.content) }
        appendMessage(TutorMessage(role: "user", content: trimmed, apiContent: enriched))
        input = ""
        referenced = []
        errorMessage = nil
        isLoading = true

        let systemPrompt = AITools.systemPrompt(profile: studentProfile())
        let context = toolContext()
        Task {
            do {
                let result = try await AITutorAgent.run(
                    config: appState.aiConfig,
                    history: history,
                    userMessage: enriched,
                    systemPrompt: systemPrompt,
                    context: context)
                appendMessage(TutorMessage(
                    role: "assistant",
                    content: result.text,
                    steps: result.steps,
                    artifacts: result.artifacts))
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    /// 追加消息并按设置持久化到当前对话
    private func appendMessage(_ message: TutorMessage) {
        messages.append(message)
        guard appState.keepChatHistory else { return }

        if currentSessionId == nil {
            let title = message.role == "user" ? sessionTitle(from: message.content) : "新对话"
            currentSessionId = appState.createChatSession(title: title)
            sessions = appState.loadChatSessions()
        }

        guard let sessionId = currentSessionId else { return }
        var record = message.record
        record.sessionId = sessionId
        appState.appendChatRecord(record)
        appState.touchChatSession(sessionId)

        // 首条用户消息用于命名对话
        if message.role == "user",
           let session = sessions.first(where: { $0.id == sessionId }),
           session.title == "新对话" {
            appState.renameChatSession(sessionId, title: sessionTitle(from: message.content))
            sessions = appState.loadChatSessions()
        }
    }

    private func sessionTitle(from text: String) -> String {
        let cleaned = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { return "新对话" }
        return String(cleaned.prefix(16))
    }

    private func loadHistory() {
        guard appState.keepChatHistory else { return }
        sessions = appState.loadChatSessions()
        if currentSessionId == nil {
            currentSessionId = sessions.first?.id
        }
        guard let id = currentSessionId else {
            messages = []
            return
        }
        messages = appState.loadChatRecords(sessionId: id).map(TutorMessage.init(record:))
    }

    // MARK: - 学员数据

    private func studentProfile() -> String {
        AITutor.studentProfile(
            counts: appState.counts,
            records: appState.records,
            wrongQuestions: appState.loadQuestions(ids: appState.wrongQuestionIds),
            favoriteQuestions: appState.loadQuestions(ids: appState.favoriteQuestionIds))
    }

    private func toolContext() -> AIToolContext {
        AIToolContext(
            bank: allBank,
            wrongQuestions: appState.loadQuestions(ids: appState.wrongQuestionIds),
            favoriteQuestions: appState.loadQuestions(ids: appState.favoriteQuestionIds),
            records: appState.records,
            defaultLevel: latestLevel)
    }

    private var latestLevel: Level {
        appState.records.first?.levelEnum ?? .a
    }

    private var filteredQuestions: [Question] {
        let s = referSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return allBank }
        return allBank.filter {
            $0.stem.localizedCaseInsensitiveContains(s)
                || $0.options.contains { $0.localizedCaseInsensitiveContains(s) }
        }
    }

    private func loadBank() {
        allBank = DatabaseManager.shared.loadAllQuestions()
    }
}

/// 引用题目的搜索选择面板（支持多选）
private struct QuestionPicker: View {
    @Binding var search: String
    let questions: [Question]
    @Binding var selected: Set<Int64>
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索题干或选项…", text: $search)
                    .textFieldStyle(.plain)
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)

            Divider().overlay(Theme.separator)

            if questions.isEmpty {
                EmptyStateView(
                    icon: "tray",
                    title: search.isEmpty ? "题库还是空的" : "没有找到相关题目",
                    message: search.isEmpty ? "请先导入题库后再引用。" : "换个关键词再试试。")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(questions) { q in
                            row(q)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Divider().overlay(Theme.separator)

            HStack(spacing: 10) {
                Text("已选 \(selected.count) 题")
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if !selected.isEmpty {
                    Button("清除") { selected.removeAll() }
                        .font(Theme.caption)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
                Button("引用") { onConfirm() }
                    .buttonStyle(PrimaryActionButton())
                    .disabled(selected.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(width: 420, height: 480)
    }

    private func row(_ q: Question) -> some View {
        let isSelected = selected.contains(q.id)
        return Button {
            if isSelected {
                selected.remove(q.id)
            } else {
                selected.insert(q.id)
            }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Theme.accent : Color.secondary.opacity(0.5))
                    .padding(.top, 1)
                Text(q.level)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("第 \(q.bankOrder) 题 · \(q.type.shortLabel)")
                        .font(Theme.caption)
                        .foregroundStyle(.secondary)
                    Text(q.stem)
                        .font(Theme.font(13))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
            .background(isSelected ? Theme.accent.opacity(0.06) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}
