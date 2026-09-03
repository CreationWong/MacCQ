//
//  SQLiteDB.swift
//  MacCQ
//
//  Created by CreationWong on 2026/9/2.
//

import Foundation
import SQLite3

enum SQLiteError: Error {
    case openFailed(String)
    case execFailed(String)
    case prepareFailed(String)
    case stepFailed(String)
}

let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// 轻量 SQLite 封装（使用系统 libsqlite3）
final class SQLiteDB {
    private(set) var handle: OpaquePointer?
    let path: String

    init(path: String) throws {
        self.path = path
        var db: OpaquePointer?
        let rc = sqlite3_open(path, &db)
        guard rc == SQLITE_OK else {
            let msg = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(db)
            throw SQLiteError.openFailed(msg)
        }
        handle = db
        sqlite3_busy_timeout(db, 3000)
    }

    func exec(_ sql: String) throws {
        guard let handle else { throw SQLiteError.execFailed("database not open") }
        var err: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(handle, sql, nil, nil, &err)
        if rc != SQLITE_OK {
            let msg = err.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(err)
            throw SQLiteError.execFailed(msg)
        }
    }

    /// 执行带绑定参数的写操作
    func run(_ sql: String, params: [Any]) throws {
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bind(params, to: stmt)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw SQLiteError.stepFailed(String(cString: sqlite3_errmsg(handle)))
        }
    }

    /// 准备一条语句用于查询
    func query(_ sql: String, params: [Any]) throws -> Statement {
        let stmt = try prepare(sql)
        try bind(params, to: stmt)
        return Statement(db: self, stmt: stmt)
    }

    func lastInsertRowID() -> Int64 { sqlite3_last_insert_rowid(handle) }

    func close() {
        if let handle { sqlite3_close(handle) }
        handle = nil
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed(String(cString: sqlite3_errmsg(handle)))
        }
        return stmt!
    }

    private func bind(_ params: [Any], to stmt: OpaquePointer) throws {
        for (i, p) in params.enumerated() {
            let idx = Int32(i + 1)
            switch p {
            case let s as String:
                sqlite3_bind_text(stmt, idx, s, -1, SQLITE_TRANSIENT)
            case let i as Int:
                sqlite3_bind_int64(stmt, idx, Int64(i))
            case let i as Int64:
                sqlite3_bind_int64(stmt, idx, i)
            case let d as Double:
                sqlite3_bind_double(stmt, idx, d)
            case let b as Bool:
                sqlite3_bind_int64(stmt, idx, b ? 1 : 0)
            case let d as Date:
                sqlite3_bind_double(stmt, idx, d.timeIntervalSince1970)
            case nil:
                sqlite3_bind_null(stmt, idx)
            default:
                sqlite3_bind_text(stmt, idx, "\(p)", -1, SQLITE_TRANSIENT)
            }
        }
    }
}

/// 可迭代的查询结果
final class Statement {
    private let stmt: OpaquePointer
    private let db: SQLiteDB
    init(db: SQLiteDB, stmt: OpaquePointer) {
        self.db = db
        self.stmt = stmt
    }

    func text(_ index: Int32) -> String {
        guard let c = sqlite3_column_text(stmt, index) else { return "" }
        return String(cString: c)
    }

    func int64(_ index: Int32) -> Int64 {
        sqlite3_column_int64(stmt, index)
    }

    func double(_ index: Int32) -> Double {
        sqlite3_column_double(stmt, index)
    }

    /// 逐行读取，返回 false 表示结束
    func step() throws -> Bool {
        let rc = sqlite3_step(stmt)
        switch rc {
        case SQLITE_ROW: return true
        case SQLITE_DONE: return false
        default:
            throw SQLiteError.stepFailed(String(cString: sqlite3_errmsg(db.handle)))
        }
    }

    func close() {
        sqlite3_finalize(stmt)
    }
}
