//
//  AITutor.swift
//  MacCQ
//

import Foundation

/// 构造 AI 辅导相关的提示词：答疑、讲解单题、练习小结、考试分析。
enum AITutor {

    static let tutorSystem = """
    你是一名中国业余无线电操作证考试的辅导老师，熟悉《业余无线电台管理办法》和相关法规、通信操作与无线电技术知识。
    请用简体中文、条理清晰地解答学员的问题：先给结论，再讲依据，必要时分点说明。
    只依据提供的资料和通用业余无线电知识作答；资料不足时请明确说明，不要编造。
    """

    static let analystSystem = """
    你是一名中国业余无线电操作证考试辅导老师。请根据学员的练习或考试情况，给出具体、可执行的学习建议。
    用简体中文作答，分点说明，控制在 300 字以内。
    """

    /// 汇总学员的题库、错题本、收藏与考试情况，供 AI 参考
    static func studentProfile(
        counts: [String: Int],
        records: [ExamRecord],
        wrongQuestions: [Question],
        favoriteQuestions: [Question]
    ) -> String {
        var lines: [String] = []

        let levelText = Level.allCases
            .map { "\($0.shortName) \(counts[$0.rawValue] ?? 0) 题" }
            .joined(separator: "，")
        lines.append("题库：\(levelText)")

        let exams = records.filter { $0.isExam }.prefix(3)
        if !exams.isEmpty {
            let text = exams.map { record -> String in
                let date = record.date.formatted(.dateTime.month().day())
                let topics = record.weakTopics.prefix(2).joined(separator: "、")
                let result = record.passed ? "合格" : "未合格"
                return "\(date) \(record.level)类 \(record.correct)/\(record.total) \(result)"
                    + (topics.isEmpty ? "" : "（薄弱：\(topics)）")
            }.joined(separator: "；")
            lines.append("最近考试：\(text)")
        }

        var topicCounts: [String: Int] = [:]
        for record in records {
            for topic in record.weakTopics {
                topicCounts[topic, default: 0] += 1
            }
        }
        if !topicCounts.isEmpty {
            let top = topicCounts
                .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
                .prefix(5)
                .map { "\($0.key)(\($0.value)次)" }
                .joined(separator: "、")
            lines.append("累计薄弱主题：\(top)")
        }

        if !wrongQuestions.isEmpty {
            let samples = wrongQuestions.prefix(4)
                .map { "\($0.level)类第\($0.bankOrder)题：\($0.stem.prefix(30))" }
                .joined(separator: "；")
            lines.append("错题本（\(wrongQuestions.count) 题）：\(samples)")
        }

        if !favoriteQuestions.isEmpty {
            let samples = favoriteQuestions.prefix(3)
                .map { "\($0.level)类第\($0.bankOrder)题：\($0.stem.prefix(30))" }
                .joined(separator: "；")
            lines.append("收藏（\(favoriteQuestions.count) 题）：\(samples)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - 答疑

    /// 把学员提问、引用题目与已有勘误组装成用户提示词。
    /// 相关题目与知识由 AI 按需通过工具查询，这里不再强行关联。
    static func chatPrompt(
        query: String,
        references: [Question],
        notes: [Int64: String] = [:]
    ) -> String {
        var sections: [String] = ["【学员问题】\n\(query)"]

        if !references.isEmpty {
            let block = references.map { q -> String in
                var text = questionBlock(q)
                if let note = notes[q.id], !note.isEmpty {
                    text += "\n用户勘误：\(note)"
                }
                return text
            }.joined(separator: "\n\n")
            sections.append("【学员引用的题目】\n\(block)")
        }

        sections.append("【回答要求】\n结合以上内容作答；需要时可以使用工具查询题库或知识库。")
        return sections.joined(separator: "\n\n")
    }

    // MARK: - 讲解单题

    static func explainPrompt(
        for question: ExamQuestion,
        knowledge: [KnowledgeEntry],
        related: [Question],
        note: String? = nil
    ) -> String {
        var sections: [String] = [
            "【题目】（\(question.type.label)）\n\(question.stem)",
            "【选项】\n" + question.options.enumerated()
                .map { "\(ExamEngine.optionLetter($0.offset)). \($0.element)" }
                .joined(separator: "\n"),
            "【正确答案】\n" + question.correctIndices.map { ExamEngine.optionLetter($0) }.joined(separator: " ")
        ]

        if let note, !note.isEmpty {
            sections.append("【用户勘误】\n学员认为本题可能有误：\(note)\n请在讲解时核实并说明。")
        }
        if !knowledge.isEmpty {
            sections.append("【相关知识要点】\n" + knowledgeBlock(knowledge))
        }
        if !related.isEmpty {
            sections.append("【同类题目】\n" + related.map { "- \($0.stem)" }.joined(separator: "\n"))
        }

        sections.append("【回答要求】\n讲清本题的考点和答题依据，并逐个说明每个选项为什么对或错。")
        return sections.joined(separator: "\n\n")
    }

    // MARK: - 练习小结

    static func summaryPrompt(
        wrong: [ExamQuestion],
        attempted: Int,
        correct: Int,
        knowledge: [KnowledgeEntry]
    ) -> String {
        let stats = "本次练习共作答 \(attempted) 题，答对 \(correct) 题，答错 \(wrong.count) 题。"

        var sections: [String] = ["【练习情况】\n\(stats)"]

        if !wrong.isEmpty {
            let lines = wrong.prefix(10).map { q -> String in
                let answer = q.correctIndices.map { ExamEngine.optionLetter($0) }.joined(separator: " ")
                return "- \(q.stem)（正确答案：\(answer)）"
            }
            sections.append("【错题】\n" + lines.joined(separator: "\n"))
        }
        if !knowledge.isEmpty {
            sections.append("【相关知识要点】\n" + knowledgeBlock(knowledge))
        }

        sections.append("【回答要求】\n分析错因和薄弱知识点，并给出接下来具体的复习建议。")
        return sections.joined(separator: "\n\n")
    }

    // MARK: - 考试分析

    static func examPrompt(analysis: StudyAnalysis) -> String {
        var sections: [String] = []

        sections.append("""
        【考试结果】
        总题数 \(analysis.total)，答对 \(analysis.correct)，答错 \(analysis.wrongCount)，\
        正确率 \(String(format: "%.0f%%", analysis.accuracy * 100))。
        """)

        if !analysis.byType.isEmpty {
            let lines = analysis.byType.map {
                "- \($0.type.label)：答对 \($0.correct)/\($0.total)"
            }
            sections.append("【分题型表现】\n" + lines.joined(separator: "\n"))
        }

        if !analysis.wrongQuestions.isEmpty {
            let lines = analysis.wrongQuestions.prefix(12).map { q -> String in
                let answer = q.correctIndices.map { ExamEngine.optionLetter($0) }.joined(separator: " ")
                return "- \(q.stem)（正确答案：\(answer)）"
            }
            sections.append("【错题】\n" + lines.joined(separator: "\n"))
        }

        if !analysis.weakTopics.isEmpty {
            sections.append("【薄弱主题】\n" + analysis.weakTopics.map { "· \($0.title)" }.joined(separator: "\n"))
        }

        sections.append("【回答要求】\n先总体评价本次考试，再指出主要薄弱点，最后给出分条的具体复习建议。")
        return sections.joined(separator: "\n\n")
    }

    // MARK: - 工具

    private static func questionBlock(_ q: Question) -> String {
        let options = q.options.enumerated()
            .map { "\(ExamEngine.optionLetter($0.offset)). \($0.element)" }
            .joined(separator: "\n")
        let answer = q.correct.sorted().map { ExamEngine.optionLetter($0) }.joined(separator: " ")
        return "【引用的题目】（\(q.type.label)，第 \(q.bankOrder) 题）\n\(q.stem)\n\(options)\n正确答案：\(answer)"
    }

    private static func knowledgeBlock(_ knowledge: [KnowledgeEntry]) -> String {
        knowledge.map { "· \($0.title)：\($0.content)" }.joined(separator: "\n")
    }
}
