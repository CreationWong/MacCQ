//
//  User.swift
//  MacCQ
//

import Foundation

/// 用户账号：仅用户名（英文 / 数字，唯一）
struct User: Identifiable, Hashable {
    var id: Int64
    var username: String
    var createdAt: Date
}

/// 练习进度：记录某用户在某道题上的作答情况
struct PracticeProgress: Identifiable, Hashable {
    var questionId: Int64
    var attempts: Int
    var correct: Int
    var lastResult: Bool
    var lastPracticedAt: Date

    var id: Int64 { questionId }
}

enum UsernameValidator {
    static let maxLength = 20

    /// 仅允许英文字母和数字，1–20 个字符
    static func isValid(_ username: String) -> Bool {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maxLength else { return false }
        return trimmed.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
    }

    static func normalized(_ username: String) -> String {
        username.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
