//
//  DatabaseManager.swift
//  MacCQ
//
//  Created by CreationWong on 2026/9/2.
//

import Foundation

/// 数据库管理器：负责题库、考试记录与 AI 配置的读写。
@MainActor
final class DatabaseManager {
    static let shared = DatabaseManager()

    private var db: SQLiteDB?
    private let dbURL: URL

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MacCQ", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        dbURL = dir.appendingPathComponent("maccq.sqlite")
        openIfNeeded()
    }

    private func openIfNeeded() {
        guard db == nil else { return }
        do {
            let db = try SQLiteDB(path: dbURL.path)
            self.db = db
            try createTables()
        } catch {
            NSLog("MacCQ: failed to open sqlite at \(dbURL.path): \(error)")
            db = nil
        }
    }

    private func createTables() throws {
        guard let db else { return }
        try db.exec("""
        CREATE TABLE IF NOT EXISTS questions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            level TEXT NOT NULL,
            qtype TEXT NOT NULL,
            stem TEXT NOT NULL,
            options TEXT NOT NULL,
            correct TEXT NOT NULL,
            bank_order INTEGER NOT NULL,
            imported_at REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_questions_level ON questions(level);

        CREATE TABLE IF NOT EXISTS exam_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            level TEXT NOT NULL,
            mode TEXT NOT NULL,
            date REAL NOT NULL,
            total INTEGER NOT NULL,
            correct INTEGER NOT NULL,
            passed INTEGER NOT NULL,
            duration INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS ai_config (
            id INTEGER PRIMARY KEY CHECK(id = 1),
            base_url TEXT,
            api_key TEXT,
            model TEXT
        );

        CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT
        );

        CREATE TABLE IF NOT EXISTS question_marks (
            question_id INTEGER NOT NULL,
            kind TEXT NOT NULL,
            marked_at REAL NOT NULL,
            PRIMARY KEY (question_id, kind)
        );

        CREATE TABLE IF NOT EXISTS question_notes (
            question_id INTEGER PRIMARY KEY,
            note TEXT NOT NULL,
            updated_at REAL NOT NULL
        );
        """)
        // 旧版本数据库升级：为考试记录补充薄弱主题列（列已存在时会报错，忽略即可）
        try? db.exec("ALTER TABLE exam_records ADD COLUMN topics TEXT")
    }

    // MARK: - 题库

    func questionCount(level: String) -> Int {
        guard let db else { return 0 }
        do {
            let stmt = try db.query("SELECT COUNT(*) FROM questions WHERE level = ?", params: [level])
            defer { stmt.close() }
            return (try stmt.step()) ? Int(stmt.int64(0)) : 0
        } catch {
            return 0
        }
    }

    func countByLevel() -> [String: Int] {
        guard let db else { return [:] }
        var result: [String: Int] = [:]
        do {
            let stmt = try db.query("SELECT level, COUNT(*) FROM questions GROUP BY level", params: [])
            defer { stmt.close() }
            while try stmt.step() {
                result[stmt.text(0)] = Int(stmt.int64(1))
            }
        } catch { }
        return result
    }

    /// 清空某个级别的题库（重新导入前使用）
    func clearQuestions(level: String) throws {
        guard let db else { return }
        try db.run("DELETE FROM questions WHERE level = ?", params: [level])
    }

    /// 批量导入题目（同一级别，先清空旧题）
    func replaceQuestions(_ questions: [Question], level: String) throws -> Int {
        guard let db else { return 0 }
        try clearQuestions(level: level)
        try db.exec("BEGIN")
        do {
            for q in questions {
                let options = try JSONSerialization.data(withJSONObject: q.options)
                let correct = try JSONSerialization.data(withJSONObject: q.correct)
                try db.run("""
                INSERT INTO questions (level, qtype, stem, options, correct, bank_order, imported_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """, params: [
                    q.level,
                    q.type.rawValue,
                    q.stem,
                    String(data: options, encoding: .utf8) ?? "[]",
                    String(data: correct, encoding: .utf8) ?? "[]",
                    q.bankOrder,
                    q.importedAt.timeIntervalSince1970,
                ])
            }
            try db.exec("COMMIT")
            return questions.count
        } catch {
            try? db.exec("ROLLBACK")
            throw error
        }
    }

    func loadQuestions(level: String) -> [Question] {
        guard let db else { return [] }
        var result: [Question] = []
        do {
            let stmt = try db.query(
                "SELECT id, level, qtype, stem, options, correct, bank_order, imported_at FROM questions WHERE level = ? ORDER BY bank_order ASC",
                params: [level])
            defer { stmt.close() }
            while try stmt.step() {
                guard var q = question(from: stmt) else { continue }
                q.id = stmt.int64(0)
                result.append(q)
            }
        } catch { }
        return result
    }

    func loadAllQuestions() -> [Question] {
        guard let db else { return [] }
        var result: [Question] = []
        do {
            let stmt = try db.query(
                "SELECT id, level, qtype, stem, options, correct, bank_order, imported_at FROM questions ORDER BY level, bank_order ASC",
                params: [])
            defer { stmt.close() }
            while try stmt.step() {
                if var q = question(from: stmt) {
                    q.id = stmt.int64(0)
                    result.append(q)
                }
            }
        } catch { }
        return result
    }

    private func question(from stmt: Statement) -> Question? {
        let qtypeRaw = stmt.text(2)
        let stem = stmt.text(3)
        let optionsStr = stmt.text(4)
        let correctStr = stmt.text(5)
        guard let qtype = QuestionType(rawValue: qtypeRaw) else { return nil }
        let options = (try? JSONSerialization.jsonObject(with: Data(optionsStr.utf8)) as? [String]) ?? []
        let correct = (try? JSONSerialization.jsonObject(with: Data(correctStr.utf8)) as? [Int]) ?? []
        return Question(
            id: 0,
            level: stmt.text(1),
            type: qtype,
            stem: stem,
            options: options,
            correct: correct,
            bankOrder: Int(stmt.int64(6)),
            importedAt: Date(timeIntervalSince1970: stmt.double(7)))
    }

    /// 按给定 ID 顺序加载题目（用于错题本与收藏）
    func loadQuestions(ids: [Int64]) -> [Question] {
        guard let db, !ids.isEmpty else { return [] }
        let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ",")
        var byId: [Int64: Question] = [:]
        do {
            let stmt = try db.query(
                "SELECT id, level, qtype, stem, options, correct, bank_order, imported_at FROM questions WHERE id IN (\(placeholders))",
                params: ids.map { $0 })
            defer { stmt.close() }
            while try stmt.step() {
                if var q = question(from: stmt) {
                    q.id = stmt.int64(0)
                    byId[q.id] = q
                }
            }
        } catch { }
        return ids.compactMap { byId[$0] }
    }

    // MARK: - 错题与收藏

    /// 添加标记（错题 / 收藏），重复添加只更新时间
    func addMark(questionId: Int64, kind: String) {
        guard let db, questionId > 0 else { return }
        try? db.run("""
        INSERT INTO question_marks (question_id, kind, marked_at) VALUES (?, ?, ?)
        ON CONFLICT(question_id, kind) DO UPDATE SET marked_at = excluded.marked_at
        """, params: [questionId, kind, Date().timeIntervalSince1970])
    }

    func removeMark(questionId: Int64, kind: String) {
        guard let db else { return }
        try? db.run("DELETE FROM question_marks WHERE question_id = ? AND kind = ?",
                    params: [questionId, kind])
    }

    func clearMarks(kind: String) {
        guard let db else { return }
        try? db.run("DELETE FROM question_marks WHERE kind = ?", params: [kind])
    }

    /// 按标记时间倒序返回题目 ID
    func loadMarkedIds(kind: String) -> [Int64] {
        guard let db else { return [] }
        var result: [Int64] = []
        do {
            let stmt = try db.query(
                "SELECT question_id FROM question_marks WHERE kind = ? ORDER BY marked_at DESC",
                params: [kind])
            defer { stmt.close() }
            while try stmt.step() {
                result.append(stmt.int64(0))
            }
        } catch { }
        return result
    }

    // MARK: - 题目勘误

    func saveNote(questionId: Int64, note: String) {
        guard let db else { return }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            try? db.run("DELETE FROM question_notes WHERE question_id = ?", params: [questionId])
        } else {
            try? db.run("""
            INSERT INTO question_notes (question_id, note, updated_at) VALUES (?, ?, ?)
            ON CONFLICT(question_id) DO UPDATE SET note = excluded.note, updated_at = excluded.updated_at
            """, params: [questionId, trimmed, Date().timeIntervalSince1970])
        }
    }

    func loadNotes() -> [Int64: String] {
        guard let db else { return [:] }
        var result: [Int64: String] = [:]
        do {
            let stmt = try db.query("SELECT question_id, note FROM question_notes", params: [])
            defer { stmt.close() }
            while try stmt.step() {
                result[stmt.int64(0)] = stmt.text(1)
            }
        } catch { }
        return result
    }

    // MARK: - 考试记录

    func saveRecord(_ record: ExamRecord) {
        guard let db else { return }
        let topics = (try? JSONSerialization.data(withJSONObject: record.weakTopics))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        try? db.run("""
        INSERT INTO exam_records (level, mode, date, total, correct, passed, duration, topics)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, params: [
            record.level,
            record.mode,
            record.date.timeIntervalSince1970,
            record.total,
            record.correct,
            record.passed,
            record.durationSeconds,
            topics,
        ])
    }

    func loadRecords() -> [ExamRecord] {
        guard let db else { return [] }
        var result: [ExamRecord] = []
        do {
            let stmt = try db.query(
                "SELECT id, level, mode, date, total, correct, passed, duration, topics FROM exam_records ORDER BY date DESC",
                params: [])
            defer { stmt.close() }
            while try stmt.step() {
                let id = stmt.int64(0)
                let level = stmt.text(1)
                let mode = stmt.text(2)
                let date = Date(timeIntervalSince1970: stmt.double(3))
                let total = Int(stmt.int64(4))
                let correct = Int(stmt.int64(5))
                let passed = stmt.int64(6) != 0
                let duration = Int(stmt.int64(7))
                let topics = (try? JSONSerialization.jsonObject(with: Data(stmt.text(8).utf8)) as? [String]) ?? []
                result.append(ExamRecord(id: id, level: level, mode: mode, date: date,
                                         total: total, correct: correct, passed: passed,
                                         durationSeconds: duration, weakTopics: topics))
            }
        } catch { }
        return result
    }

    func clearRecords() {
        guard let db else { return }
        try? db.exec("DELETE FROM exam_records")
    }

    // MARK: - AI 配置

    func loadAIConfig() -> AIConfig {
        guard let db else { return AIConfig() }
        do {
            let stmt = try db.query("SELECT base_url, api_key, model FROM ai_config WHERE id = 1", params: [])
            defer { stmt.close() }
            if try stmt.step() {
                return AIConfig(baseURL: stmt.text(0), apiKey: stmt.text(1), model: stmt.text(2))
            }
        } catch { }
        return AIConfig()
    }

    func saveAIConfig(_ config: AIConfig) {
        guard let db else { return }
        try? db.run("""
        INSERT INTO ai_config (id, base_url, api_key, model) VALUES (1, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET base_url = excluded.base_url, api_key = excluded.api_key, model = excluded.model
        """, params: [config.baseURL, config.apiKey, config.model])
    }
}
