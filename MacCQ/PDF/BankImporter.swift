//
//  BankImporter.swift
//  MacCQ
//
//  Created by CreationWong on 2026/9/2.
//

import Foundation
import PDFKit

enum ImportError: Error {
    case cannotRead
    case unsupportedFormat(String)
}

struct ImportReport {
    var questions: [Question]
    var detected: Int
    var valid: Int
    var dropped: Int
    var unresolved: [UnresolvedQuestion]
    var level: String
}

/// 无法自动导入、需要人工确认的题目。
struct UnresolvedQuestion: Identifiable {
    let id: Int
    let number: Int
    let stem: String
    let options: [String]
    let reason: String
}

/// 题库导入器：读取 PDF（PDFKit 抽取文本）或 TXT，并解析为题目列表。
enum BankImporter {

    /// 根据文件名推断级别（A类/B类/C类），无法识别时返回 nil
    static func detectLevel(from url: URL) -> Level? {
        let name = url.lastPathComponent
        for l in Level.allCases {
            if name.contains("\(l.rawValue)类") || name.contains("\(l.rawValue)证") {
                return l
            }
        }
        return nil
    }

    static func extractText(from url: URL) throws -> String {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        switch url.pathExtension.lowercased() {
        case "pdf":
            guard let doc = PDFDocument(url: url) else { throw ImportError.cannotRead }
            var text = ""
            for i in 0..<doc.pageCount {
                if let s = doc.page(at: i)?.string {
                    text += s + "\n"
                }
            }
            return text
        case "txt", "text", "md":
            return try String(contentsOf: url, encoding: .utf8)
        default:
            throw ImportError.unsupportedFormat(url.pathExtension)
        }
    }

    /// 从文件导入题库，level 由调用方指定
    static func importBank(from url: URL, level: String) throws -> ImportReport {
        let text = try extractText(from: url)
        let parsed = QuestionParser.parse(text: text)
        var questions: [Question] = []
        var valid = 0
        var dropped = 0
        var unresolved: [UnresolvedQuestion] = []
        for (i, p) in parsed.enumerated() {
            let oldCorrect = p.correctLetters.compactMap { letterIndex($0) }

            // 去重选项并重映射正确答案（防止源数据中同一选项文本重复出现）
            var firstSeen: [String: Int] = [:]
            var uniqueOptions: [String] = []
            var remap: [Int] = []
            for text in p.options {
                let key = text.trimmingCharacters(in: .whitespaces).lowercased()
                if let existing = firstSeen[key] {
                    remap.append(existing)
                } else {
                    let newIndex = uniqueOptions.count
                    firstSeen[key] = newIndex
                    uniqueOptions.append(text)
                    remap.append(newIndex)
                }
            }
            // A malformed answer may reference an option that was not parsed
            // (for example, answer D with only A-C options). Keep it for the
            // manual-review list instead of indexing past the remap array.
            let hasOutOfRangeAnswer = oldCorrect.contains { remap[safe: $0] == nil }
            var correct = oldCorrect.compactMap { remap[safe: $0] }
            correct = Array(Set(correct)).sorted()

            let indicesValid = !hasOutOfRangeAnswer && correct.allSatisfy { $0 < uniqueOptions.count }
            guard !correct.isEmpty, indicesValid, uniqueOptions.count >= 2 else {
                dropped += 1
                let reason: String
                if p.options.count < 2 {
                    reason = "选项不足（至少需要 2 个选项）"
                } else if hasOutOfRangeAnswer {
                    reason = "正确答案超出选项范围"
                } else if correct.isEmpty {
                    reason = "未识别到正确答案"
                } else { reason = "无法验证正确答案" }
                unresolved.append(UnresolvedQuestion(id: i, number: i + 1,
                                                     stem: p.stem,
                                                     options: p.options,
                                                     reason: reason))
                continue
            }
            questions.append(Question(
                id: 0,
                level: level,
                type: p.type,
                stem: p.stem,
                options: uniqueOptions,
                correct: correct,
                bankOrder: i + 1,
                importedAt: Date()))
            valid += 1
        }
        return ImportReport(questions: questions, detected: parsed.count,
                            valid: valid, dropped: dropped,
                            unresolved: unresolved, level: level)
    }

    private static func letterIndex(_ letter: String) -> Int? {
        guard let scalar = letter.uppercased().unicodeScalars.first else { return nil }
        let value = Int(scalar.value)
        let base = Int(UnicodeScalar("A").value)
        guard value >= base, value <= base + 7 else { return nil }
        return value - base
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
