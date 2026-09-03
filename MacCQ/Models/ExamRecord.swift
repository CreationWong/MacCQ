//
//  ExamRecord.swift
//  MacCQ
//
//  Created by CreationWong on 2026/9/2.
//

import Foundation

/// 一次练习或模拟考试的记录
struct ExamRecord: Codable, Identifiable {
    var id: Int64 = 0
    var level: String        // A / B / C
    var mode: String         // exam / practice
    var date: Date
    var total: Int           // 试卷总题数
    var correct: Int         // 答对题数
    var passed: Bool         // 是否合格（练习模式可为空/always true）
    var durationSeconds: Int // 用时

    var levelEnum: Level? { Level(rawValue: level) }
    var isExam: Bool { mode == "exam" }
}
