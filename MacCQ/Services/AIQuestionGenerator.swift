//
//  AIQuestionGenerator.swift
//  MacCQ
//

import Foundation

/// AI 生成的一道题（用于解析 JSON 返回）
struct GeneratedQuestion: Decodable {
    let type: String?
    let stem: String
    let options: [String]
    let answer: AnswerValue
    let explanation: String?

    enum AnswerValue: Decodable {
        case text(String)
        case list([String])

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let text = try? container.decode(String.self) {
                self = .text(text)
            } else if let list = try? container.decode([String].self) {
                self = .list(list)
            } else {
                throw DecodingError.typeMismatch(
                    AnswerValue.self,
                    DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "answer 必须是字符串或字符串数组"))
            }
        }

        /// 提取答案字母（忽略大小写、空格、逗号等）
        var letters: [String] {
            switch self {
            case .text(let text):
                return AnswerValue.extract(from: text)
            case .list(let list):
                return list.flatMap { AnswerValue.extract(from: $0) }
            }
        }

        private static func extract(from string: String) -> [String] {
            string.uppercased().filter { ("A"..."H").contains($0) }.map(String.init)
        }
    }
}

/// AI 命题：让模型针对薄弱知识点生成一套练习题，并解析为可作答的题目。
enum AIQuestionGenerator {

    static let systemPrompt = """
    你是一名中国业余无线电操作证考试的命题老师，熟悉《业余无线电台管理办法》和操作技术能力验证大纲。
    请严格按照要求的 JSON 格式出题，只输出 JSON 数组，不要输出任何解释性文字或 Markdown 代码块。
    题目必须符合中国现行法规和技术常识，每题有明确、唯一的正确答案。
    """

    static func userPrompt(level: Level, topics: [String], knowledge: [KnowledgeEntry], count: Int) -> String {
        var sections: [String] = []

        let topicList = topics.isEmpty
            ? "无线电管理法规、通信操作、系统原理、安全防护、电磁兼容"
            : topics.map { "- \($0)" }.joined(separator: "\n")
        sections.append("请针对以下薄弱知识点，为 \(level.name)考试出 \(count) 道题：\n\(topicList)")

        if !knowledge.isEmpty {
            let block = knowledge.map { "· \($0.title)：\($0.content)" }.joined(separator: "\n")
            sections.append("可参考的知识要点：\n\(block)")
        }

        sections.append("""
        要求：
        1. 题型用 single（单选）或 multi（多选）；单选只有 1 个正确答案，多选有 2 个及以上正确答案。
        2. 每题提供 4 个选项，选项文字不要带 A/B/C/D 前缀。
        3. answer 用大写字母表示，如 "A" 或 "ABC"。
        4. 每题给出简短解析（explanation）。
        5. 只输出 JSON 数组，格式如下：
        [{"type":"single","stem":"题干","options":["选项1","选项2","选项3","选项4"],"answer":"A","explanation":"解析"}]
        """)

        return sections.joined(separator: "\n\n")
    }

    /// 将 AI 返回的文本解析为可作答的题目
    static func parse(_ response: String, level: Level) -> [ExamQuestion] {
        let json = extractJSON(from: response)
        guard let data = json.data(using: .utf8),
              let items = try? JSONDecoder().decode([GeneratedQuestion].self, from: data) else {
            return []
        }
        return examQuestions(from: items, level: level)
    }

    /// 把已解码的题目转换为可作答的题目
    static func examQuestions(from items: [GeneratedQuestion], level: Level) -> [ExamQuestion] {
        items.enumerated().compactMap { makeQuestion($0.element, index: $0.offset, level: level) }
    }

    /// 容错提取 JSON：去掉 Markdown 代码块和前后多余文字
    static func extractJSON(from text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = result.firstIndex(of: "["),
           let end = result.lastIndex(of: "]"),
           start < end {
            result = String(result[start...end])
        }
        return result
    }

    // MARK: - 内部

    private static func makeQuestion(_ item: GeneratedQuestion, index: Int, level: Level) -> ExamQuestion? {
        let stem = item.stem.trimmingCharacters(in: .whitespacesAndNewlines)
        let options = item.options.map(cleanOption).filter { !$0.isEmpty }
        guard !stem.isEmpty, options.count >= 2 else { return nil }

        var indices: [Int] = []
        for letter in item.answer.letters {
            guard let scalar = letter.unicodeScalars.first else { continue }
            let value = Int(scalar.value) - Int(UnicodeScalar("A").value)
            if value >= 0, value < options.count, !indices.contains(value) {
                indices.append(value)
            }
        }
        indices.sort()
        guard !indices.isEmpty else { return nil }

        let type: QuestionType = indices.count > 1 ? .multi : .single
        return ExamQuestion(
            id: -Int64(index + 1),
            level: level.rawValue,
            type: type,
            stem: stem,
            options: options,
            correctIndices: indices,
            bankOrder: index + 1,
            explanation: item.explanation?.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// 去掉选项可能带有的 "A." / "A、" / "(A)" 前缀
    private static func cleanOption(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^\(?[A-Ha-h]\)?\s*[、．.，,：:]\s*"#
        if let re = try? NSRegularExpression(pattern: pattern),
           let match = re.firstMatch(in: result, range: NSRange(result.startIndex..., in: result)),
           let range = Range(match.range, in: result) {
            result = String(result[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        return result
    }
}
