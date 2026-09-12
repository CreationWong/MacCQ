//
//  TextSimilarity.swift
//  MacCQ
//

import Foundation

/// 轻量中文文本相似度：基于字符二元组（bigram）重合度，无需分词。
enum TextSimilarity {

    /// 提取文本的字符二元组集合（忽略标点与空白）
    static func bigrams(_ text: String) -> Set<String> {
        let chars = Array(text.lowercased().filter { $0.isLetter || $0.isNumber })
        guard chars.count >= 2 else {
            return Set(chars.map(String.init))
        }
        var result = Set<String>()
        for i in 0..<(chars.count - 1) {
            result.insert(String(chars[i...i + 1]))
        }
        return result
    }

    /// 两段文本的共同二元组数量
    static func score(_ a: String, _ b: String) -> Int {
        let grams = bigrams(a)
        guard !grams.isEmpty else { return 0 }
        return grams.intersection(bigrams(b)).count
    }
}
