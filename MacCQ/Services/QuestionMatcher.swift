//
//  QuestionMatcher.swift
//  MacCQ
//

import Foundation

/// 从题库中自动关联与问题（或某道题）最相关的题目。
enum QuestionMatcher {

    /// 根据一段文本，从题库中找出最相关的题目
    static func related(to query: String, bank: [Question], excludingId: Int64? = nil, limit: Int = 5) -> [Question] {
        let queryGrams = TextSimilarity.bigrams(query)
        guard !queryGrams.isEmpty else { return [] }

        var scored: [(question: Question, score: Int)] = []
        for q in bank where q.id != excludingId {
            let text = q.stem + " " + q.options.joined(separator: " ")
            let overlap = queryGrams.intersection(TextSimilarity.bigrams(text)).count
            guard overlap > 0 else { continue }

            var score = overlap
            let prefix = String(q.stem.prefix(8))
            if query.contains(prefix) { score += 4 }
            scored.append((q, score))
        }

        scored.sort { $0.score != $1.score ? $0.score > $1.score : $0.question.bankOrder < $1.question.bankOrder }

        // 优先返回相关度较高的结果；若都不够突出，则退回相关度最高的少量题目。
        let strong = scored.filter { $0.score >= 2 }
        let chosen = strong.isEmpty ? scored : strong
        return chosen.prefix(limit).map { $0.question }
    }

    /// 找出一组题目的同类相关题（用于「举一反三」）
    static func related(to question: Question, bank: [Question], limit: Int = 4) -> [Question] {
        related(
            to: question.stem + " " + question.options.joined(separator: " "),
            bank: bank,
            excludingId: question.id,
            limit: limit)
    }
}
