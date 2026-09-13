//
//  DatabaseManager.swift
//  MacCQ
//
//  Created by CreationWong on 2026/9/2.
//

import Foundation

/// 数据库管理器：负责题库、用户、学习进度、考试记录与 AI 配置的读写。
/// 题库为整机共享；错题、收藏、勘误、练习进度、考试记录、对话都按用户隔离。
@MainActor
final class DatabaseManager {
    static let shared = DatabaseManager()

    private var db: SQLiteDB?
    private let dbURL: URL

    /// 当前登录用户；0 表示未登录（旧数据归属）
    private(set) var currentUserId: Int64 = 0

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

        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL UNIQUE COLLATE NOCASE,
            created_at REAL NOT NULL
        );

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
            user_id INTEGER NOT NULL DEFAULT 0,
            question_id INTEGER NOT NULL,
            kind TEXT NOT NULL,
            marked_at REAL NOT NULL,
            PRIMARY KEY (user_id, question_id, kind)
        );

        CREATE TABLE IF NOT EXISTS question_notes (
            user_id INTEGER NOT NULL DEFAULT 0,
            question_id INTEGER NOT NULL,
            note TEXT NOT NULL,
            updated_at REAL NOT NULL,
            PRIMARY KEY (user_id, question_id)
        );

        CREATE TABLE IF NOT EXISTS practice_progress (
            user_id INTEGER NOT NULL,
            question_id INTEGER NOT NULL,
            attempts INTEGER NOT NULL DEFAULT 0,
            correct INTEGER NOT NULL DEFAULT 0,
            last_result INTEGER NOT NULL DEFAULT 0,
            last_practiced_at REAL NOT NULL,
            PRIMARY KEY (user_id, question_id)
        );

        CREATE TABLE IF NOT EXISTS chat_messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            api_content TEXT,
            steps TEXT,
            artifacts TEXT,
            created_at REAL NOT NULL,
            session_id INTEGER
        );

        CREATE TABLE IF NOT EXISTS chat_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );
        """)

        // 旧版本数据库升级：为考试记录补充薄弱主题列（列已存在时会报错，忽略即可）
        try? db.exec("ALTER TABLE exam_records ADD COLUMN topics TEXT")
        // 旧版本对话记录升级：补充会话列并归档到「历史对话」
        try? db.exec("ALTER TABLE chat_messages ADD COLUMN session_id INTEGER")
        try? db.exec("""
        INSERT INTO chat_sessions (title, created_at, updated_at)
        SELECT '历史对话', MIN(created_at), MAX(created_at)
        FROM chat_messages WHERE session_id IS NULL HAVING COUNT(*) > 0
        """)
        try? db.exec("""
        UPDATE chat_messages SET session_id = (SELECT MAX(id) FROM chat_sessions)
        WHERE session_id IS NULL
        """)

        migrateUserColumns(in: db)
    }

    /// 为老数据库补充 user_id 列；错题/勘误表需要重建主键
    private func migrateUserColumns(in db: SQLiteDB) {
        if !hasColumn("exam_records", "user_id") {
            try? db.exec("ALTER TABLE exam_records ADD COLUMN user_id INTEGER NOT NULL DEFAULT 0")
        }
        if !hasColumn("chat_sessions", "user_id") {
            try? db.exec("ALTER TABLE chat_sessions ADD COLUMN user_id INTEGER NOT NULL DEFAULT 0")
        }
        if !hasColumn("question_marks", "user_id") {
            try? db.exec("""
            CREATE TABLE IF NOT EXISTS question_marks_new (
                user_id INTEGER NOT NULL DEFAULT 0,
                question_id INTEGER NOT NULL,
                kind TEXT NOT NULL,
                marked_at REAL NOT NULL,
                PRIMARY KEY (user_id, question_id, kind)
            );
            INSERT OR IGNORE INTO question_marks_new (user_id, question_id, kind, marked_at)
            SELECT 0, question_id, kind, marked_at FROM question_marks;
            DROP TABLE question_marks;
            ALTER TABLE question_marks_new RENAME TO question_marks;
            """)
        }
        if !hasColumn("question_notes", "user_id") {
            try? db.exec("""
            CREATE TABLE IF NOT EXISTS question_notes_new (
                user_id INTEGER NOT NULL DEFAULT 0,
                question_id INTEGER NOT NULL,
                note TEXT NOT NULL,
                updated_at REAL NOT NULL,
                PRIMARY KEY (user_id, question_id)
            );
            INSERT OR IGNORE INTO question_notes_new (user_id, question_id, note, updated_at)
            SELECT 0, question_id, note, updated_at FROM question_notes;
            DROP TABLE question_notes;
            ALTER TABLE question_notes_new RENAME TO question_notes;
            """)
        }
    }

    private func hasColumn(_ table: String, _ column: String) -> Bool {
        guard let db else { return false }
        do {
            let stmt = try db.query("PRAGMA table_info(\(table))", params: [])
            defer { stmt.close() }
            while try stmt.step() {
                if stmt.text(1) == column { return true }
            }
        } catch { }
        return false
    }

    // MARK: - 用户

    func setCurrentUser(_ id: Int64) {
        currentUserId = id
    }

    /// 注册用户；用户名非法或已存在时返回 nil
    func createUser(username: String) -> User? {
        guard let db else { return nil }
        let name = UsernameValidator.normalized(username)
        guard UsernameValidator.isValid(name), findUser(username: name) == nil else { return nil }
        let isFirstUser = loadUsers().isEmpty
        let now = Date().timeIntervalSince1970
        try? db.run("INSERT INTO users (username, created_at) VALUES (?, ?)", params: [name, now])
        let id = db.lastInsertRowID()
        guard id > 0 else { return nil }
        // 首个账号继承升级前属于本机的学习数据
        if isFirstUser {
            adoptLegacyData(userId: id)
        }
        return User(id: id, username: name, createdAt: Date(timeIntervalSince1970: now))
    }

    /// 把旧版本（无用户概念，user_id = 0）的数据归属到指定用户
    private func adoptLegacyData(userId: Int64) {
        guard let db else { return }
        try? db.run("UPDATE exam_records SET user_id = ? WHERE user_id = 0", params: [userId])
        try? db.run("UPDATE question_marks SET user_id = ? WHERE user_id = 0", params: [userId])
        try? db.run("UPDATE question_notes SET user_id = ? WHERE user_id = 0", params: [userId])
        try? db.run("UPDATE chat_sessions SET user_id = ? WHERE user_id = 0", params: [userId])
        try? db.run("UPDATE practice_progress SET user_id = ? WHERE user_id = 0", params: [userId])
    }

    func findUser(username: String) -> User? {
        guard let db else { return nil }
        let name = UsernameValidator.normalized(username)
        do {
            let stmt = try db.query(
                "SELECT id, username, created_at FROM users WHERE username = ? COLLATE NOCASE",
                params: [name])
            defer { stmt.close() }
            if try stmt.step() {
                return user(from: stmt)
            }
        } catch { }
        return nil
    }

    func findUser(id: Int64) -> User? {
        guard let db, id > 0 else { return nil }
        do {
            let stmt = try db.query(
                "SELECT id, username, created_at FROM users WHERE id = ?",
                params: [id])
            defer { stmt.close() }
            if try stmt.step() {
                return user(from: stmt)
            }
        } catch { }
        return nil
    }

    func loadUsers() -> [User] {
        guard let db else { return [] }
        var result: [User] = []
        do {
            let stmt = try db.query(
                "SELECT id, username, created_at FROM users ORDER BY created_at ASC",
                params: [])
            defer { stmt.close() }
            while try stmt.step() {
                if let user = user(from: stmt) { result.append(user) }
            }
        } catch { }
        return result
    }

    private func user(from stmt: Statement) -> User? {
        User(
            id: stmt.int64(0),
            username: stmt.text(1),
            createdAt: Date(timeIntervalSince1970: stmt.double(2)))
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

    /// 清空某个级别的题库（重新导入前使用），并清理相关的个人数据
    func clearQuestions(level: String) throws {
        guard let db else { return }
        try db.run("DELETE FROM question_marks WHERE question_id IN (SELECT id FROM questions WHERE level = ?)", params: [level])
        try db.run("DELETE FROM question_notes WHERE question_id IN (SELECT id FROM questions WHERE level = ?)", params: [level])
        try db.run("DELETE FROM practice_progress WHERE question_id IN (SELECT id FROM questions WHERE level = ?)", params: [level])
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
        INSERT INTO question_marks (user_id, question_id, kind, marked_at) VALUES (?, ?, ?, ?)
        ON CONFLICT(user_id, question_id, kind) DO UPDATE SET marked_at = excluded.marked_at
        """, params: [currentUserId, questionId, kind, Date().timeIntervalSince1970])
    }

    func removeMark(questionId: Int64, kind: String) {
        guard let db else { return }
        try? db.run("DELETE FROM question_marks WHERE user_id = ? AND question_id = ? AND kind = ?",
                    params: [currentUserId, questionId, kind])
    }

    func clearMarks(kind: String) {
        guard let db else { return }
        try? db.run("DELETE FROM question_marks WHERE user_id = ? AND kind = ?",
                    params: [currentUserId, kind])
    }

    /// 按标记时间倒序返回题目 ID
    func loadMarkedIds(kind: String) -> [Int64] {
        guard let db else { return [] }
        var result: [Int64] = []
        do {
            let stmt = try db.query(
                "SELECT question_id FROM question_marks WHERE user_id = ? AND kind = ? ORDER BY marked_at DESC",
                params: [currentUserId, kind])
            defer { stmt.close() }
            while try stmt.step() {
                result.append(stmt.int64(0))
            }
        } catch { }
        return result
    }

    // MARK: - 练习进度

    func recordPractice(questionId: Int64, correct: Bool) {
        guard let db, questionId > 0 else { return }
        try? db.run("""
        INSERT INTO practice_progress (user_id, question_id, attempts, correct, last_result, last_practiced_at)
        VALUES (?, ?, 1, ?, ?, ?)
        ON CONFLICT(user_id, question_id) DO UPDATE SET
            attempts = attempts + 1,
            correct = correct + excluded.correct,
            last_result = excluded.last_result,
            last_practiced_at = excluded.last_practiced_at
        """, params: [
            currentUserId,
            questionId,
            correct ? 1 : 0,
            correct ? 1 : 0,
            Date().timeIntervalSince1970,
        ])
    }

    func loadPracticeProgress() -> [Int64: PracticeProgress] {
        guard let db else { return [:] }
        var result: [Int64: PracticeProgress] = [:]
        do {
            let stmt = try db.query(
                "SELECT question_id, attempts, correct, last_result, last_practiced_at FROM practice_progress WHERE user_id = ?",
                params: [currentUserId])
            defer { stmt.close() }
            while try stmt.step() {
                let id = stmt.int64(0)
                result[id] = PracticeProgress(
                    questionId: id,
                    attempts: Int(stmt.int64(1)),
                    correct: Int(stmt.int64(2)),
                    lastResult: stmt.int64(3) != 0,
                    lastPracticedAt: Date(timeIntervalSince1970: stmt.double(4)))
            }
        } catch { }
        return result
    }

    func clearPracticeProgress() {
        guard let db else { return }
        try? db.run("DELETE FROM practice_progress WHERE user_id = ?", params: [currentUserId])
    }

    // MARK: - 题目勘误

    func saveNote(questionId: Int64, note: String) {
        guard let db else { return }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            try? db.run("DELETE FROM question_notes WHERE user_id = ? AND question_id = ?",
                        params: [currentUserId, questionId])
        } else {
            try? db.run("""
            INSERT INTO question_notes (user_id, question_id, note, updated_at) VALUES (?, ?, ?, ?)
            ON CONFLICT(user_id, question_id) DO UPDATE SET note = excluded.note, updated_at = excluded.updated_at
            """, params: [currentUserId, questionId, trimmed, Date().timeIntervalSince1970])
        }
    }

    func loadNotes() -> [Int64: String] {
        guard let db else { return [:] }
        var result: [Int64: String] = [:]
        do {
            let stmt = try db.query(
                "SELECT question_id, note FROM question_notes WHERE user_id = ?",
                params: [currentUserId])
            defer { stmt.close() }
            while try stmt.step() {
                result[stmt.int64(0)] = stmt.text(1)
            }
        } catch { }
        return result
    }

    // MARK: - 对话记录

    @discardableResult
    func createChatSession(title: String) -> Int64 {
        guard let db else { return 0 }
        let now = Date().timeIntervalSince1970
        try? db.run(
            "INSERT INTO chat_sessions (title, created_at, updated_at, user_id) VALUES (?, ?, ?, ?)",
            params: [title, now, now, currentUserId])
        return db.lastInsertRowID()
    }

    func loadChatSessions() -> [ChatSession] {
        guard let db else { return [] }
        var result: [ChatSession] = []
        do {
            let stmt = try db.query(
                "SELECT id, title, created_at, updated_at FROM chat_sessions WHERE user_id = ? ORDER BY updated_at DESC",
                params: [currentUserId])
            defer { stmt.close() }
            while try stmt.step() {
                result.append(ChatSession(
                    id: stmt.int64(0),
                    title: stmt.text(1),
                    createdAt: Date(timeIntervalSince1970: stmt.double(2)),
                    updatedAt: Date(timeIntervalSince1970: stmt.double(3))))
            }
        } catch { }
        return result
    }

    func sessionBelongsToCurrentUser(_ id: Int64) -> Bool {
        guard let db else { return false }
        do {
            let stmt = try db.query("SELECT 1 FROM chat_sessions WHERE id = ? AND user_id = ?",
                                    params: [id, currentUserId])
            defer { stmt.close() }
            return try stmt.step()
        } catch { }
        return false
    }

    func renameChatSession(id: Int64, title: String) {
        guard let db else { return }
        try? db.run("UPDATE chat_sessions SET title = ?, updated_at = ? WHERE id = ? AND user_id = ?",
                    params: [title, Date().timeIntervalSince1970, id, currentUserId])
    }

    func touchChatSession(id: Int64) {
        guard let db else { return }
        try? db.run("UPDATE chat_sessions SET updated_at = ? WHERE id = ? AND user_id = ?",
                    params: [Date().timeIntervalSince1970, id, currentUserId])
    }

    func deleteChatSession(id: Int64) {
        guard let db, sessionBelongsToCurrentUser(id) else { return }
        try? db.run("DELETE FROM chat_messages WHERE session_id = ?", params: [id])
        try? db.run("DELETE FROM chat_sessions WHERE id = ? AND user_id = ?", params: [id, currentUserId])
    }

    func clearChatSession(id: Int64) {
        guard let db, sessionBelongsToCurrentUser(id) else { return }
        try? db.run("DELETE FROM chat_messages WHERE session_id = ?", params: [id])
    }

    func clearAllChat() {
        guard let db else { return }
        try? db.run("DELETE FROM chat_messages WHERE session_id IN (SELECT id FROM chat_sessions WHERE user_id = ?)",
                    params: [currentUserId])
        try? db.run("DELETE FROM chat_sessions WHERE user_id = ?", params: [currentUserId])
    }

    @discardableResult
    func appendChatMessage(_ record: ChatMessageRecord) -> Int64 {
        guard let db, sessionBelongsToCurrentUser(record.sessionId) else { return 0 }
        let steps = (try? JSONEncoder().encode(record.steps))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        let artifacts = (try? JSONEncoder().encode(record.artifacts))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        try? db.run("""
        INSERT INTO chat_messages (session_id, role, content, api_content, steps, artifacts, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """, params: [
            record.sessionId,
            record.role,
            record.content,
            record.apiContent ?? "",
            steps,
            artifacts,
            record.createdAt.timeIntervalSince1970,
        ])
        return db.lastInsertRowID()
    }

    func loadChatMessages(sessionId: Int64) -> [ChatMessageRecord] {
        guard let db, sessionBelongsToCurrentUser(sessionId) else { return [] }
        var result: [ChatMessageRecord] = []
        do {
            let stmt = try db.query(
                "SELECT id, role, content, api_content, steps, artifacts, created_at FROM chat_messages WHERE session_id = ? ORDER BY id ASC",
                params: [sessionId])
            defer { stmt.close() }
            while try stmt.step() {
                let apiContent = stmt.text(3)
                let steps = (try? JSONDecoder().decode([AgentStep].self, from: Data(stmt.text(4).utf8))) ?? []
                let artifacts = (try? JSONDecoder().decode([StoredArtifact].self, from: Data(stmt.text(5).utf8))) ?? []
                result.append(ChatMessageRecord(
                    id: stmt.int64(0),
                    role: stmt.text(1),
                    content: stmt.text(2),
                    apiContent: apiContent.isEmpty ? nil : apiContent,
                    steps: steps,
                    artifacts: artifacts,
                    createdAt: Date(timeIntervalSince1970: stmt.double(6)),
                    sessionId: sessionId))
            }
        } catch { }
        return result
    }

    // MARK: - 通用设置

    func getSetting(_ key: String) -> String? {
        guard let db else { return nil }
        do {
            let stmt = try db.query("SELECT value FROM settings WHERE key = ?", params: [key])
            defer { stmt.close() }
            if try stmt.step() {
                return stmt.text(0)
            }
        } catch { }
        return nil
    }

    func setSetting(_ key: String, value: String) {
        guard let db else { return }
        try? db.run("""
        INSERT INTO settings (key, value) VALUES (?, ?)
        ON CONFLICT(key) DO UPDATE SET value = excluded.value
        """, params: [key, value])
    }

    func deleteSetting(_ key: String) {
        guard let db else { return }
        try? db.run("DELETE FROM settings WHERE key = ?", params: [key])
    }

    // MARK: - 考试记录

    func saveRecord(_ record: ExamRecord) {
        guard let db else { return }
        let topics = (try? JSONSerialization.data(withJSONObject: record.weakTopics))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        try? db.run("""
        INSERT INTO exam_records (level, mode, date, total, correct, passed, duration, topics, user_id)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, params: [
            record.level,
            record.mode,
            record.date.timeIntervalSince1970,
            record.total,
            record.correct,
            record.passed,
            record.durationSeconds,
            topics,
            currentUserId,
        ])
    }

    func loadRecords() -> [ExamRecord] {
        guard let db else { return [] }
        var result: [ExamRecord] = []
        do {
            let stmt = try db.query(
                "SELECT id, level, mode, date, total, correct, passed, duration, topics FROM exam_records WHERE user_id = ? ORDER BY date DESC",
                params: [currentUserId])
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
        try? db.run("DELETE FROM exam_records WHERE user_id = ?", params: [currentUserId])
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
