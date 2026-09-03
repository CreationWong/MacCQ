//
//  Question.swift
//  MacCQ
//
//  Created by CreationWong on 2026/9/2.
//

import Foundation

/// 题型：单选 / 多选
enum QuestionType: String, Codable, CaseIterable {
    case single
    case multi

    var label: String {
        switch self {
        case .single: return "单选题"
        case .multi: return "多选题"
        }
    }

    var shortLabel: String {
        switch self {
        case .single: return "单选"
        case .multi: return "多选"
        }
    }
}

/// 一道题目（数据库映射）
struct Question: Codable, Identifiable, Hashable {
    var id: Int64 = 0
    var level: String        // A / B / C
    var type: QuestionType
    var stem: String
    var options: [String]
    var correct: [Int]       // 正确选项在原选项中的索引（0-based，多选为多个）
    var bankOrder: Int       // 在题库中的原始顺序
    var importedAt: Date     // 导入时间
}
