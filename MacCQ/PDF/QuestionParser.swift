//
//  QuestionParser.swift
//  MacCQ
//
//  Created by CreationWong on 2026/9/2.
//

import Foundation

struct ParsedQuestion {
    var type: QuestionType
    var stem: String
    var options: [String]
    var correctLetters: [String]
}

/// 题库解析器：从提取到的纯文本中解析出题目。
/// 支持两种格式：
/// 1. 带标签格式（[J]/[P]/[I]/[Q]/[T]/[A]...）：`[Q]`题干、`[T]`答案、`[A]-[H]`选项；
///    `[T]` 为一个字母即单选，多于一个即多选。
/// 2. 常见别名格式：编号（`1、` / `第1题` / `1．`）、选项（`A．` / `A、` / `A.` / `(A)`）、答案行（`答案：A`）。
enum QuestionParser {

    static func parse(text: String) -> [ParsedQuestion] {
        let lines = normalize(text)
        // 带标签格式检测
        if lines.contains(where: { $0.hasPrefix("[Q]") }) {
            return parseTagged(lines)
        }
        return parseCommon(lines)
    }

    // MARK: - 带标签格式

    private static func parseTagged(_ lines: [String]) -> [ParsedQuestion] {
        var result: [ParsedQuestion] = []
        var stem = ""
        var options: [String] = []
        var answer: [String] = []
        var started = false

        func finalize() {
            let cleanStem = stem.trimmingCharacters(in: .whitespacesAndNewlines)
            let hasValid = started && !cleanStem.isEmpty && options.count >= 2 && !answer.isEmpty
            if hasValid {
                let type: QuestionType = answer.count > 1 ? .multi : .single
                result.append(ParsedQuestion(type: type, stem: cleanStem,
                                             options: options, correctLetters: answer))
            }
            stem = ""; options = []; answer = []; started = false
        }

        for line in lines {
            if line.isEmpty { continue }
            if line.hasPrefix("[Q]") {
                finalize()
                started = true
                stem = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                continue
            }
            if line.hasPrefix("[T]") {
                answer = lettersIn(String(line.dropFirst(3)))
                continue
            }
            if taggedOptionLetter(line) != nil {
                let idx = line.range(of: "]")?.upperBound ?? line.startIndex
                let rest = String(line[idx...])
                options.append(rest.trimmingCharacters(in: .whitespaces))
                continue
            }
            // 元数据行直接忽略
            if line.hasPrefix("[J]") || line.hasPrefix("[P]") || line.hasPrefix("[I]") { continue }
            // 题干续行
            // PDF text extraction often wraps one sentence across lines. Join
            // continuation lines with a space so punctuation is not stranded
            // at the start of a new rendered line.
            if started { stem += (stem.isEmpty ? "" : " ") + line }
        }
        finalize()
        return result
    }

    /// 匹配 `[A]`…`[H]` 选项行，返回字母
    private static func taggedOptionLetter(_ line: String) -> String? {
        let pattern = #"^\[([A-H])\]"#
        guard let re = try? NSRegularExpression(pattern: pattern),
              let result = match(re, in: line) else { return nil }
        return capture(result, at: 1, in: line)
    }

    /// 提取字符串中出现的大写字母 A-H（去掉其它字符）
    private static func lettersIn(_ string: String) -> [String] {
        let range: ClosedRange<Character> = "A"..."H"
        return string.uppercased().filter { range.contains($0) }.map { String($0) }
    }

    // MARK: - 常见格式

    private static func parseCommon(_ lines: [String]) -> [ParsedQuestion] {
        var questions: [ParsedQuestion] = []
        var current: Builder?

        for line in lines {
            if line.isEmpty { continue }

            if let answer = answerLetters(from: line) {
                current?.correct = answer
                continue
            }
            if let opt = optionPart(from: line) {
                current?.options.append(opt)
                continue
            }
            if let header = questionHeader(from: line) {
                if let c = current, !(c.stem.isEmpty && c.options.isEmpty) {
                    finalize(c, into: &questions)
                }
                current = Builder(type: header.type, stem: header.stem)
                continue
            }
            current?.appendStem(line)
        }
        if let c = current { finalize(c, into: &questions) }
        return questions
    }

    private static func normalize(_ text: String) -> [String] {
        text.replacingOccurrences(of: "\u{0C}", with: "\n") // form-feed page break
            .replacingOccurrences(of: "\u{2028}", with: "\n")
            .replacingOccurrences(of: "\u{2029}", with: "\n")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: .newlines)
            .map {
                $0.replacingOccurrences(of: "\u{200B}", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
    }

    // MARK: - 内部构建器

    private struct Builder {
        var type: QuestionType
        var stem: String
        var options: [String] = []
        var correct: [String] = []

        mutating func appendStem(_ line: String) {
            stem += (stem.isEmpty ? "" : " ") + line
        }
    }

    private static func finalize(_ b: Builder, into out: inout [ParsedQuestion]) {
        let cleanStem = b.stem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !b.options.isEmpty, b.options.count >= 2, !cleanStem.isEmpty else { return }
        out.append(ParsedQuestion(type: b.type, stem: cleanStem, options: b.options, correctLetters: b.correct))
    }

    // MARK: - 识别

    private struct Header {
        var type: QuestionType
        var stem: String
    }

    /// 检测题目起始行，返回题型与题干文本
    private static func questionHeader(from line: String) -> Header? {
        let prefixPattern = #"^\s*(?:第\s*)?(\d+)\s*(?:题\s*)?[、．.，,：:(（]"#
        guard let re = try? NSRegularExpression(pattern: prefixPattern),
              let result = match(re, in: line) else { return nil }
        guard let prefixRange = Range(result.range, in: line) else { return nil }
        var rest = String(line[prefixRange.upperBound...]).trimmingCharacters(in: .whitespaces)

        let type: QuestionType = rest.contains("多选") ? .multi : .single

        // 去掉题型词与引导冒号
        if let re2 = try? NSRegularExpression(pattern: #"^(?:单选|多选|单项选择|多项选择)\s*题?\s*[:：]?"#),
           let r = match(re2, in: rest),
           let range = Range(r.range, in: rest) {
            rest = String(rest[range.upperBound...])
        }
        // 去掉引导括号与空白
        rest = rest.trimmingCharacters(in: CharacterSet(charactersIn: "、．.，,：:)(（）"))
        rest = rest.trimmingCharacters(in: .whitespacesAndNewlines)
        // 去掉填空占位
        rest = rest.replacingOccurrences(of: "（  ）", with: "")
        rest = rest.replacingOccurrences(of: "（ ）", with: "")
        rest = rest.replacingOccurrences(of: "(  )", with: "")
        rest = rest.replacingOccurrences(of: "( )", with: "")
        rest = rest.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rest.isEmpty else { return nil }
        return Header(type: type, stem: rest)
    }

    /// 检测选项行，返回选项文本（去掉字母前缀）
    private static func optionPart(from line: String) -> String? {
        let pattern = #"^\(?([A-H])\)?\s*[、．.，,：:]\s*"#
        guard let re = try? NSRegularExpression(pattern: pattern),
              let result = match(re, in: line),
              let r = Range(result.range, in: line) else { return nil }
        let optionText = String(line[r.upperBound...]).trimmingCharacters(in: .whitespaces)
        guard !optionText.isEmpty else { return nil }
        return optionText
    }

    /// 检测答案行，返回字母列表（如 ["A","B"]）
    private static func answerLetters(from line: String) -> [String]? {
        let pattern = #"^\s*[【\(\[]?\s*(?:参考答案|正确答案|标准答案|答案)\s*[:：]?\s*([A-H]+)"#
        guard let re = try? NSRegularExpression(pattern: pattern),
              let result = match(re, in: line),
              let letters = capture(result, at: 1, in: line) else { return nil }
        return letters.map { String($0) }
    }

    // MARK: - Regex 工具

    private static func match(_ re: NSRegularExpression, in string: String) -> NSTextCheckingResult? {
        re.firstMatch(in: string, options: [], range: NSRange(string.startIndex..., in: string))
    }

    private static func capture(_ result: NSTextCheckingResult, at index: Int, in string: String) -> String? {
        guard index < result.numberOfRanges else { return nil }
        let ns = result.range(at: index)
        guard ns.location != NSNotFound, let r = Range(ns, in: string) else { return nil }
        return String(string[r])
    }
}
