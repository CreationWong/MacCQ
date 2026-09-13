//
//  MarkdownView.swift
//  MacCQ
//

import SwiftUI

/// 安全渲染行内 Markdown（粗体/斜体/代码），保留空白，移除链接与远程图片。
func safeInlineMarkdown(_ text: String) -> AttributedString {
    guard !text.isEmpty else { return AttributedString(text) }
    let options = AttributedString.MarkdownParsingOptions(
        interpretedSyntax: .inlineOnlyPreservingWhitespace,
        failurePolicy: .returnPartiallyParsedIfPossible)
    guard let parsed = try? AttributedString(markdown: text, options: options) else {
        return AttributedString(text)
    }
    var result = AttributedString()
    for run in parsed.runs {
        var attrs = run.attributes
        attrs.link = nil
        attrs.imageURL = nil
        var sub = parsed[run.range]
        sub.setAttributes(attrs)
        result.append(sub)
    }
    return result
}

// MARK: - 块级解析

struct MarkdownListItem: Identifiable {
    let id = UUID()
    let depth: Int
    let marker: String
    let text: String
}

struct MarkdownBlock: Identifiable {
    enum Kind {
        case heading(level: Int, text: String)
        case paragraph(String)
        case bullets([MarkdownListItem])
        case ordered([MarkdownListItem])
        case code(String)
        case quote(String)
    }

    let id = UUID()
    let kind: Kind
}

/// Markdown 块级解析器（供渲染与测试使用）
enum MarkdownParser {

    static func parse(_ text: String) -> [MarkdownBlock] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")

        var blocks: [MarkdownBlock] = []
        var i = 0

        while i < lines.count {
            let raw = lines[i]
            let trimmed = raw.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                i += 1
                continue
            }

            // 代码块
            if trimmed.hasPrefix("```") {
                var code: [String] = []
                i += 1
                while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(lines[i])
                    i += 1
                }
                if i < lines.count { i += 1 }
                blocks.append(MarkdownBlock(kind: .code(code.joined(separator: "\n"))))
                continue
            }

            // 标题
            if let heading = heading(trimmed) {
                blocks.append(MarkdownBlock(kind: .heading(level: heading.level, text: heading.text)))
                i += 1
                continue
            }

            // 引用
            if trimmed.hasPrefix(">") {
                var quote: [String] = []
                while i < lines.count, lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                    let line = lines[i].trimmingCharacters(in: .whitespaces)
                    quote.append(String(line.dropFirst()).trimmingCharacters(in: .whitespaces))
                    i += 1
                }
                blocks.append(MarkdownBlock(kind: .quote(quote.joined(separator: "\n"))))
                continue
            }

            // 无序列表
            if bullet(raw) != nil {
                var items: [MarkdownListItem] = []
                while i < lines.count, let item = bullet(lines[i]) {
                    items.append(item)
                    i += 1
                }
                blocks.append(MarkdownBlock(kind: .bullets(items)))
                continue
            }

            // 有序列表
            if ordered(raw) != nil {
                var items: [MarkdownListItem] = []
                while i < lines.count, let item = ordered(lines[i]) {
                    items.append(item)
                    i += 1
                }
                blocks.append(MarkdownBlock(kind: .ordered(items)))
                continue
            }

            // 段落
            var paragraph: [String] = [trimmed]
            i += 1
            while i < lines.count {
                let next = lines[i]
                let nextTrimmed = next.trimmingCharacters(in: .whitespaces)
                if nextTrimmed.isEmpty || isBlockStart(next) { break }
                paragraph.append(nextTrimmed)
                i += 1
            }
            blocks.append(MarkdownBlock(kind: .paragraph(paragraph.joined(separator: "\n"))))
        }

        return blocks
    }

    private static func isBlockStart(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("```")
            || trimmed.hasPrefix(">")
            || heading(trimmed) != nil
            || bullet(line) != nil
            || ordered(line) != nil
    }

    private static func heading(_ line: String) -> (level: Int, text: String)? {
        let hashes = line.prefix(while: { $0 == "#" })
        guard !hashes.isEmpty, hashes.count <= 6 else { return nil }
        let rest = line.dropFirst(hashes.count)
        guard rest.hasPrefix(" ") else { return nil }
        return (hashes.count, rest.trimmingCharacters(in: .whitespaces))
    }

    private static func bullet(_ line: String) -> MarkdownListItem? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") else { return nil }
        let indent = line.prefix(while: { $0 == " " }).count
        return MarkdownListItem(
            depth: min(indent / 2, 3),
            marker: "•",
            text: String(trimmed.dropFirst(2)))
    }

    private static func ordered(_ line: String) -> MarkdownListItem? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let digits = trimmed.prefix(while: { $0.isNumber })
        guard !digits.isEmpty else { return nil }
        let rest = trimmed.dropFirst(digits.count)
        guard rest.hasPrefix(". ") || rest.hasPrefix(") ") else { return nil }
        let indent = line.prefix(while: { $0 == " " }).count
        return MarkdownListItem(
            depth: min(indent / 2, 3),
            marker: "\(digits).",
            text: String(rest.dropFirst(2)))
    }
}

// MARK: - 渲染

/// 轻量 Markdown 渲染：段落、标题、有序/无序列表、引用、代码块。
struct MarkdownView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(MarkdownParser.parse(text)) { block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block.kind {
        case .heading(let level, let text):
            Text(safeInlineMarkdown(text))
                .font(headingFont(level))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, level <= 2 ? 2 : 0)

        case .paragraph(let text):
            Text(safeInlineMarkdown(text))
                .font(Theme.body)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

        case .bullets(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items) { item in
                    listRow(marker: item.marker, item: item)
                }
            }

        case .ordered(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    listRow(marker: "\(index + 1).", item: item)
                }
            }

        case .code(let code):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(10)
            }
            .background(Theme.surfaceMuted, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 1))

        case .quote(let text):
            HStack(alignment: .top, spacing: 10) {
                Rectangle()
                    .fill(Theme.accent.opacity(0.5))
                    .frame(width: 3)
                Text(safeInlineMarkdown(text))
                    .font(Theme.body)
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func listRow(marker: String, item: MarkdownListItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(marker)
                .font(Theme.body)
                .foregroundStyle(.secondary)
                .frame(minWidth: 16, alignment: .trailing)
            Text(safeInlineMarkdown(item.text))
                .font(Theme.body)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, CGFloat(item.depth) * 16)
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return Theme.font(19, .bold)
        case 2: return Theme.font(16, .semibold)
        default: return Theme.font(15, .semibold)
        }
    }
}
