//
//  AppState.swift
//  MacCQ
//
//  Created by CreationWong on 2026/9/2.
//

import Foundation
import Observation

/// 全局共享状态：题库数量、考试记录、AI 配置等
@MainActor
@Observable
final class AppState {
    var counts: [String: Int] = [:]
    var records: [ExamRecord] = []
    var aiConfig: AIConfig = AIConfig()
    var lastImport: ImportReport?
    var wrongQuestionIds: [Int64] = []
    var favoriteQuestionIds: [Int64] = []
    var notes: [Int64: String] = [:]
    var keepChatHistory: Bool = true

    init() {
        refresh()
    }

    func refresh() {
        counts = DatabaseManager.shared.countByLevel()
        records = DatabaseManager.shared.loadRecords()
        aiConfig = DatabaseManager.shared.loadAIConfig()
        wrongQuestionIds = DatabaseManager.shared.loadMarkedIds(kind: "wrong")
        favoriteQuestionIds = DatabaseManager.shared.loadMarkedIds(kind: "favorite")
        notes = DatabaseManager.shared.loadNotes()
        keepChatHistory = (DatabaseManager.shared.getSetting("keep_chat_history") ?? "1") == "1"
    }

    func count(for level: Level) -> Int {
        counts[level.rawValue] ?? 0
    }

    @discardableResult
    func importBank(url: URL, level: Level) throws -> ImportReport {
        let report = try BankImporter.importBank(from: url, level: level.rawValue)
        // 没有识别到任何题目时不替换原题库，避免误选文件清空已有题目。
        if !report.questions.isEmpty {
            _ = try DatabaseManager.shared.replaceQuestions(report.questions, level: level.rawValue)
        }
        lastImport = report
        refresh()
        return report
    }

    func recordFinished(level: Level, mode: String, total: Int, correct: Int, duration: Int, weakTopics: [String] = []) {
        let passed = mode == "exam" ? level.passed(correctCount: correct) : true
        let rec = ExamRecord(id: 0, level: level.rawValue, mode: mode, date: Date(),
                             total: total, correct: correct, passed: passed,
                             durationSeconds: duration, weakTopics: weakTopics)
        DatabaseManager.shared.saveRecord(rec)
        refresh()
    }

    func saveAIConfig(_ config: AIConfig) {
        DatabaseManager.shared.saveAIConfig(config)
        aiConfig = config
    }

    // MARK: - 错题与收藏

    func addWrongQuestion(_ id: Int64) {
        guard id > 0, !wrongQuestionIds.contains(id) else { return }
        DatabaseManager.shared.addMark(questionId: id, kind: "wrong")
        wrongQuestionIds.insert(id, at: 0)
    }

    func removeWrongQuestion(_ id: Int64) {
        DatabaseManager.shared.removeMark(questionId: id, kind: "wrong")
        wrongQuestionIds.removeAll { $0 == id }
    }

    func clearWrongQuestions() {
        DatabaseManager.shared.clearMarks(kind: "wrong")
        wrongQuestionIds = []
    }

    func clearFavorites() {
        DatabaseManager.shared.clearMarks(kind: "favorite")
        favoriteQuestionIds = []
    }

    func isFavorite(_ id: Int64) -> Bool {
        favoriteQuestionIds.contains(id)
    }

    func toggleFavorite(_ id: Int64) {
        guard id > 0 else { return }
        if favoriteQuestionIds.contains(id) {
            DatabaseManager.shared.removeMark(questionId: id, kind: "favorite")
            favoriteQuestionIds.removeAll { $0 == id }
        } else {
            DatabaseManager.shared.addMark(questionId: id, kind: "favorite")
            favoriteQuestionIds.insert(id, at: 0)
        }
    }

    // MARK: - 题目勘误

    func note(for id: Int64) -> String? {
        notes[id]
    }

    func saveNote(_ note: String, for id: Int64) {
        DatabaseManager.shared.saveNote(questionId: id, note: note)
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            notes[id] = nil
        } else {
            notes[id] = trimmed
        }
    }

    /// 按 ID 顺序加载错题/收藏题目
    func loadQuestions(ids: [Int64]) -> [Question] {
        DatabaseManager.shared.loadQuestions(ids: ids)
    }

    // MARK: - 对话记录

    func setKeepChatHistory(_ value: Bool) {
        keepChatHistory = value
        DatabaseManager.shared.setSetting("keep_chat_history", value: value ? "1" : "0")
    }

    @discardableResult
    func createChatSession(title: String) -> Int64 {
        DatabaseManager.shared.createChatSession(title: title)
    }

    func loadChatSessions() -> [ChatSession] {
        guard keepChatHistory else { return [] }
        return DatabaseManager.shared.loadChatSessions()
    }

    func renameChatSession(_ id: Int64, title: String) {
        DatabaseManager.shared.renameChatSession(id: id, title: title)
    }

    func touchChatSession(_ id: Int64) {
        DatabaseManager.shared.touchChatSession(id: id)
    }

    func deleteChatSession(_ id: Int64) {
        DatabaseManager.shared.deleteChatSession(id: id)
    }

    func clearChatSession(_ id: Int64) {
        DatabaseManager.shared.clearChatSession(id: id)
    }

    func appendChatRecord(_ record: ChatMessageRecord) {
        guard keepChatHistory else { return }
        _ = DatabaseManager.shared.appendChatMessage(record)
    }

    func loadChatRecords(sessionId: Int64) -> [ChatMessageRecord] {
        guard keepChatHistory else { return [] }
        return DatabaseManager.shared.loadChatMessages(sessionId: sessionId)
    }

    func clearChatHistory() {
        DatabaseManager.shared.clearAllChat()
    }
}

/// 侧边栏导航路由
enum Route: Hashable, Identifiable {
    case importBank
    case practice(Level)
    case exam(Level)
    case notebook
    case records
    case ai
    case settings

    var id: String {
        switch self {
        case .importBank: return "import"
        case .practice(let l): return "practice-\(l.rawValue)"
        case .exam(let l): return "exam-\(l.rawValue)"
        case .notebook: return "notebook"
        case .records: return "records"
        case .ai: return "ai"
        case .settings: return "settings"
        }
    }
}
