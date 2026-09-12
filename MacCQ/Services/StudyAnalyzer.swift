//
//  StudyAnalyzer.swift
//  MacCQ
//

import Foundation

/// 某个题型的正确率
struct TypeAccuracy: Identifiable {
    let type: QuestionType
    let correct: Int
    let total: Int

    var id: String { type.rawValue }
    var accuracy: Double { total == 0 ? 0 : Double(correct) / Double(total) }
}

/// 需要重点复习的知识主题
struct TopicFocus: Identifiable {
    let title: String
    let count: Int
    var id: String { title }
}

/// 一次练习或考试的分析结果
struct StudyAnalysis {
    let total: Int
    let correct: Int
    let answered: Int
    let wrongQuestions: [ExamQuestion]
    let byType: [TypeAccuracy]
    let weakTopics: [TopicFocus]
    let suggestions: [String]

    var accuracy: Double { total == 0 ? 0 : Double(correct) / Double(total) }
    var wrongCount: Int { wrongQuestions.count }
}

/// 本地学习分析：统计正确率、薄弱题型与知识主题，并给出复习建议。
enum StudyAnalyzer {

    /// 分析一份完整试卷（考试场景）
    static func analyze(paper: [ExamQuestion], answers: [Int: Set<Int>]) -> StudyAnalysis {
        var correct = 0
        var answered = 0
        var wrong: [ExamQuestion] = []
        var typeCorrect: [QuestionType: Int] = [:]
        var typeTotal: [QuestionType: Int] = [:]

        for (i, q) in paper.enumerated() {
            let answer = answers[i] ?? []
            typeTotal[q.type, default: 0] += 1
            if !answer.isEmpty { answered += 1 }
            if ExamEngine.isCorrect(answer: answer, for: q) {
                correct += 1
                typeCorrect[q.type, default: 0] += 1
            } else {
                wrong.append(q)
            }
        }

        let byType = QuestionType.allCases.compactMap { type -> TypeAccuracy? in
            guard let total = typeTotal[type], total > 0 else { return nil }
            return TypeAccuracy(type: type, correct: typeCorrect[type] ?? 0, total: total)
        }

        let topics = weakTopics(for: wrong)
        let suggestions = buildSuggestions(
            total: paper.count, correct: correct, answered: answered,
            byType: byType, topics: topics)

        return StudyAnalysis(total: paper.count, correct: correct, answered: answered,
                             wrongQuestions: wrong, byType: byType,
                             weakTopics: topics, suggestions: suggestions)
    }

    /// 分析练习中做错的题目
    static func analyze(wrongQuestions: [ExamQuestion], attempted: Int, correct: Int) -> StudyAnalysis {
        let topics = weakTopics(for: wrongQuestions)
        let suggestions = buildSuggestions(
            total: attempted, correct: correct, answered: attempted,
            byType: [], topics: topics)

        return StudyAnalysis(total: attempted, correct: correct, answered: attempted,
                             wrongQuestions: wrongQuestions, byType: [],
                             weakTopics: topics, suggestions: suggestions)
    }

    // MARK: - 内部

    /// 统计错题命中的知识主题
    private static func weakTopics(for questions: [ExamQuestion]) -> [TopicFocus] {
        var counts: [String: Int] = [:]
        for q in questions {
            let text = q.stem + " " + q.options.joined(separator: " ")
            for entry in KnowledgeBase.search(text, limit: 2) {
                counts[entry.title, default: 0] += 1
            }
        }
        return counts
            .map { TopicFocus(title: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.title < $1.title }
    }

    private static func buildSuggestions(
        total: Int, correct: Int, answered: Int,
        byType: [TypeAccuracy], topics: [TopicFocus]
    ) -> [String] {
        guard total > 0 else {
            return ["完成一次练习或考试后，这里会给出针对性的复习建议。"]
        }

        let accuracy = Double(correct) / Double(total)
        var suggestions: [String] = []

        if accuracy >= 0.9 {
            suggestions.append("整体掌握得很好，保持现在的复习节奏即可。")
        } else if accuracy >= 0.75 {
            suggestions.append("基础比较扎实，把个别薄弱点补齐就更稳了。")
        } else if accuracy >= 0.6 {
            suggestions.append("部分知识点还不够牢固，建议按下面的薄弱主题重点复习。")
        } else {
            suggestions.append("基础还比较薄弱，建议先系统复习安全知识，再反复练习错题。")
        }

        if let multi = byType.first(where: { $0.type == .multi }),
           let single = byType.first(where: { $0.type == .single }),
           multi.accuracy + 0.1 < single.accuracy {
            suggestions.append("多选题准确率偏低，答题时逐项判断，避免漏选或多选。")
        }

        if answered < total {
            suggestions.append("有 \(total - answered) 题未作答，考试时注意先易后难、合理分配时间。")
        }

        if !topics.isEmpty {
            let names = topics.prefix(3).map(\.title).joined(separator: "、")
            suggestions.append("重点复习：\(names)。")
        }

        if correct < total {
            suggestions.append("把错题重新做一遍，弄清每个选项对错的原因。")
        }

        return suggestions
    }
}
