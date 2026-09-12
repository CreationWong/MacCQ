//
//  ExamEngine.swift
//  MacCQ
//
//  Created by CreationWong on 2026/9/2.
//

import Foundation

/// 试卷中的一道题：选项顺序已打乱，正确索引指向打乱后的选项
struct ExamQuestion: Identifiable, Hashable {
    let id: Int64
    let level: String
    let type: QuestionType
    let stem: String
    let options: [String]
    let correctIndices: [Int]
    let bankOrder: Int
    /// AI 生成题目的解析（题库题目为 nil）
    var explanation: String? = nil
}

/// 组卷与阅卷引擎
enum ExamEngine {

    /// 从题库抽题：题目保持题库中的原始顺序，仅打乱每题选项位置；正确项跟随变化
    static func buildExam(bank: [Question], count: Int) -> [ExamQuestion] {
        let ordered = bank.sorted { $0.bankOrder < $1.bankOrder }
        let chosen: [Question]
        if ordered.count <= count {
            chosen = ordered
        } else {
            chosen = Array(ordered.shuffled().prefix(count)).sorted { $0.bankOrder < $1.bankOrder }
        }
        return chosen.map { q in
            let pairs = q.options.indices.map { ($0, q.options[$0]) }.shuffled()
            let options = pairs.map { $0.1 }
            let correctSet = Set(q.correct)
            var correctIndices: [Int] = []
            for (i, pair) in pairs.enumerated() where correctSet.contains(pair.0) {
                correctIndices.append(i)
            }
            correctIndices.sort()
            return ExamQuestion(id: q.id, level: q.level, type: q.type,
                                stem: q.stem, options: options,
                                correctIndices: correctIndices, bankOrder: q.bankOrder)
        }
    }

    /// 判断某题作答是否全对（单选须唯一、多选须全选对）
    static func isCorrect(answer: Set<Int>, for q: ExamQuestion) -> Bool {
        Set(q.correctIndices) == answer
    }

    /// 整卷阅卷，返回答对数与错题序号
    static func gradePaper(exam: [ExamQuestion], answers: [Int: Set<Int>]) -> (correct: Int, wrong: [Int]) {
        var correct = 0
        var wrong: [Int] = []
        for (i, q) in exam.enumerated() {
            if isCorrect(answer: answers[i] ?? [], for: q) {
                correct += 1
            } else {
                wrong.append(i)
            }
        }
        return (correct, wrong)
    }

    /// 选项字母（A/B/C/D...）
    static func optionLetter(_ index: Int) -> String {
        guard index >= 0 else { return "" }
        let base = Int(UnicodeScalar("A").value)
        let value = base + index
        guard let scalar = UnicodeScalar(value) else { return "" }
        return String(Character(scalar))
    }
}
