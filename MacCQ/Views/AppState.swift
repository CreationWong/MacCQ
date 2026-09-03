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

    init() {
        refresh()
    }

    func refresh() {
        counts = DatabaseManager.shared.countByLevel()
        records = DatabaseManager.shared.loadRecords()
        aiConfig = DatabaseManager.shared.loadAIConfig()
    }

    func count(for level: Level) -> Int {
        counts[level.rawValue] ?? 0
    }

    @discardableResult
    func importBank(url: URL, level: Level) throws -> ImportReport {
        let report = try BankImporter.importBank(from: url, level: level.rawValue)
        _ = try DatabaseManager.shared.replaceQuestions(report.questions, level: level.rawValue)
        lastImport = report
        refresh()
        return report
    }

    func recordFinished(level: Level, mode: String, total: Int, correct: Int, duration: Int) {
        let passed = mode == "exam" ? level.passed(correctCount: correct) : true
        let rec = ExamRecord(id: 0, level: level.rawValue, mode: mode, date: Date(),
                             total: total, correct: correct, passed: passed,
                             durationSeconds: duration)
        DatabaseManager.shared.saveRecord(rec)
        refresh()
    }

    func saveAIConfig(_ config: AIConfig) {
        DatabaseManager.shared.saveAIConfig(config)
        aiConfig = config
    }
}

/// 侧边栏导航路由
enum Route: Hashable, Identifiable {
    case importBank
    case practice(Level)
    case exam(Level)
    case records
    case ai
    case settings

    var id: String {
        switch self {
        case .importBank: return "import"
        case .practice(let l): return "practice-\(l.rawValue)"
        case .exam(let l): return "exam-\(l.rawValue)"
        case .records: return "records"
        case .ai: return "ai"
        case .settings: return "settings"
        }
    }
}
