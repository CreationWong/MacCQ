//
//  Design.swift
//  MacCQ
//
//  Created by CreationWong on 2026/9/2.
//

import SwiftUI

/// 安全渲染 Markdown：保留常见排版（粗体/斜体/代码/列表），
/// 但移除超链接与远程图片，防止渲染层注入（点击跳转、追踪外链、加载恶意资源）。
func safeMarkdownText(_ text: String) -> AttributedString {
    guard !text.isEmpty else { return AttributedString(text) }
    let options = AttributedString.MarkdownParsingOptions(
        interpretedSyntax: .full,
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

/// macOS 液态玻璃设计系统
enum MacDesign {
    static let accentTint = Color(red: 0.20, green: 0.47, blue: 0.96)

    /// 根据系统外观（浅色/深色）动态解析的颜色
    private static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua])
            return match == .darkAqua ? dark : light
        })
    }

    // 窗口背景：柔和渐变 + 顶部辉光（浅/深色自动适配）
    static let bgTop = adaptive(
        light: NSColor(red: 0.99, green: 0.99, blue: 1.00, alpha: 1),
        dark: NSColor(red: 0.11, green: 0.12, blue: 0.16, alpha: 1))
    static let bgMid = adaptive(
        light: NSColor(red: 0.93, green: 0.96, blue: 1.00, alpha: 1),
        dark: NSColor(red: 0.09, green: 0.11, blue: 0.15, alpha: 1))
    static let bgBottom = adaptive(
        light: NSColor(red: 0.88, green: 0.93, blue: 0.99, alpha: 1),
        dark: NSColor(red: 0.07, green: 0.08, blue: 0.12, alpha: 1))

    static let windowGradient = LinearGradient(
        colors: [bgTop, bgMid, bgBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing)

    static let glow = RadialGradient(
        colors: [adaptive(light: .white.withAlphaComponent(0.9), dark: .white.withAlphaComponent(0.10)), Color.clear],
        center: .topLeading,
        startRadius: 0,
        endRadius: 700)

    @ViewBuilder
    static var background: some View {
        ZStack {
            windowGradient
            glow.blendMode(.screen)
        }
        .ignoresSafeArea()
    }

    // 玻璃表面描边与弱填充（浅/深色自动适配）
    static let glassBorder = adaptive(
        light: NSColor.white.withAlphaComponent(0.45),
        dark: NSColor.white.withAlphaComponent(0.22))
    static let subtleFill = adaptive(
        light: NSColor.white.withAlphaComponent(0.25),
        dark: NSColor.white.withAlphaComponent(0.12))

    // 排版
    static let title = Font.system(.title, design: .rounded, weight: .semibold)
    static let subtitle = Font.system(.title3, design: .rounded)
    static let cardTitle = Font.system(.headline, design: .rounded)
}

/// 玻璃卡片：液态玻璃质感 + 细描边
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat
    init(cornerRadius: CGFloat = 20) { self.cornerRadius = cornerRadius }

    func body(content: Content) -> some View {
        content
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(MacDesign.glassBorder, lineWidth: 0.6)
            )
    }
}

/// 玻璃描边胶囊（按钮/徽章）：使用系统原生液态玻璃
struct GlassPill: ViewModifier {
    var cornerRadius: CGFloat
    var tint: Color?
    init(cornerRadius: CGFloat = 10, tint: Color? = nil) {
        self.cornerRadius = cornerRadius
        self.tint = tint
    }

    func body(content: Content) -> some View {
        content
            .glassEffect(
                tint.map { .regular.tint($0) } ?? .regular,
                in: .rect(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(MacDesign.glassBorder, lineWidth: 0.5)
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }

    func glassPill(cornerRadius: CGFloat = 10, tint: Color? = nil) -> some View {
        modifier(GlassPill(cornerRadius: cornerRadius, tint: tint))
    }

    /// 可交互（可点击）的液态玻璃表面：悬停/按下时呈现系统玻璃反馈
    func glassCardInteractive(cornerRadius: CGFloat = 20) -> some View {
        self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
    }
}
