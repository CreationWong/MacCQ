//
//  AITrainingService.swift
//  MacCQ
//

import Foundation

/// 讲解幻灯片（类似 PPT 的一页）
struct LessonSlide: Identifiable, Decodable {
    let title: String
    let points: [String]
    let example: String?

    var id: String { title + points.joined() }
}

/// AI 训练相关的检索辅助：主题知识、真题选取。
enum AITrainingService {

    /// 该主题对应的知识要点
    static func topicKnowledge(for topic: String) -> [KnowledgeEntry] {
        if let exact = KnowledgeBase.all.first(where: { $0.title == topic }) {
            return [exact]
        }
        return KnowledgeBase.search(topic, limit: 2)
    }

    /// 根据主题从题库中挑选真题，优先错题本与收藏中的题目
    static func selectRealQuestions(
        topic: String,
        level: Level?,
        bank: [Question],
        wrongIds: Set<Int64>,
        favoriteIds: Set<Int64>,
        limit: Int = 10
    ) -> [Question] {
        guard !bank.isEmpty else { return [] }

        let knowledge = topicKnowledge(for: topic)
        let corpus = ([topic] + knowledge.map { $0.title + $0.keywords.joined() + $0.content })
            .joined(separator: " ")
        let topicGrams = TextSimilarity.bigrams(corpus)
        guard !topicGrams.isEmpty else { return [] }

        var scored: [(question: Question, score: Int)] = []
        for q in bank {
            if let level, q.level != level.rawValue { continue }
            let text = q.stem + " " + q.options.joined(separator: " ")
            var score = topicGrams.intersection(TextSimilarity.bigrams(text)).count
            guard score > 0 else { continue }
            if wrongIds.contains(q.id) { score += 8 }
            if favoriteIds.contains(q.id) { score += 5 }
            scored.append((q, score))
        }

        scored.sort { $0.score != $1.score ? $0.score > $1.score : $0.question.bankOrder < $1.question.bankOrder }

        let strong = scored.filter { $0.score >= 3 }
        let chosen = strong.isEmpty ? scored : strong
        return Array(chosen.prefix(limit).map { $0.question })
    }
}
