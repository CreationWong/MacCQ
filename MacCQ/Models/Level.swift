//
//  Level.swift
//  MacCQ
//
//  Created by CreationWong on 2026/9/2.
//

import Foundation

/// 操作证级别 A、B、C，C 最高
enum Level: String, CaseIterable, Codable, Identifiable {
    case a = "A"
    case b = "B"
    case c = "C"

    var id: String { rawValue }

    var name: String { "\(rawValue)类操作技术能力" }

    var shortName: String { "\(rawValue)类" }

    var questionCount: Int {
        switch self {
        case .a: return 30
        case .b: return 50
        case .c: return 80
        }
    }

    var timeMinutes: Int {
        switch self {
        case .a: return 40
        case .b: return 60
        case .c: return 90
        }
    }

    var timeSeconds: Int { timeMinutes * 60 }

    var passCount: Int {
        switch self {
        case .a: return 25
        case .b: return 40
        case .c: return 60
        }
    }

    var passPercent: Double {
        guard questionCount > 0 else { return 0 }
        return Double(passCount) / Double(questionCount)
    }

    /// 考试是否通过
    func passed(correctCount: Int) -> Bool {
        correctCount >= passCount
    }
}
