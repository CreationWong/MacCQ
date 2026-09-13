//
//  Design.swift
//  MacCQ
//

import SwiftUI

/// 全局视觉风格：克制的配色、统一的间距与字体、简洁的组件。
/// 遵循系统浅色/深色外观自动适配。
enum Theme {

    // MARK: - 颜色

    static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }

    /// 主题强调色，用于关键操作与选中状态
    static let accent = Color(red: 0.20, green: 0.45, blue: 0.92)

    /// 页面画布
    static let canvas = adaptive(
        light: NSColor(white: 0.955, alpha: 1),
        dark: NSColor(white: 0.075, alpha: 1))

    /// 卡片表面
    static let surface = adaptive(
        light: .white,
        dark: NSColor(white: 0.125, alpha: 1))

    /// 次级表面（输入框、选项底、空状态等）
    static let surfaceMuted = adaptive(
        light: NSColor(white: 0.965, alpha: 1),
        dark: NSColor(white: 0.165, alpha: 1))

    /// 描边
    static let border = adaptive(
        light: NSColor(white: 0.87, alpha: 1),
        dark: NSColor(white: 0.24, alpha: 1))

    /// 分隔线
    static let separator = adaptive(
        light: NSColor(white: 0.90, alpha: 1),
        dark: NSColor(white: 0.20, alpha: 1))

    static let shadow = Color.black.opacity(0.05)

    // 状态色
    static let success = Color(red: 0.13, green: 0.62, blue: 0.36)
    static let danger = Color(red: 0.85, green: 0.24, blue: 0.24)
    static let warning = Color(red: 0.88, green: 0.55, blue: 0.12)

    // MARK: - 字体

    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static let pageTitle = font(26, .bold)
    static let sectionTitle = font(15, .semibold)
    static let cardTitle = font(16, .semibold)
    static let body = font(14)
    static let label = font(13, .medium)
    static let caption = font(12)
    static let mono = font(20, .semibold).monospacedDigit()
}

// MARK: - 卡片

private struct CardModifier: ViewModifier {
    var padding: CGFloat
    var radius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 1))
            .shadow(color: Theme.shadow, radius: 10, x: 0, y: 3)
    }
}

extension View {
    /// 统一的卡片外观：表面填充 + 细描边 + 轻投影
    func card(padding: CGFloat = 20, radius: CGFloat = 14) -> some View {
        modifier(CardModifier(padding: padding, radius: radius))
    }

    /// 页面背景
    func pageBackground() -> some View {
        background(Theme.canvas.ignoresSafeArea())
    }
}

// MARK: - 按钮

/// 主操作按钮：实心强调色
struct PrimaryActionButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(14, .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(
                Theme.accent.opacity(configuration.isPressed ? 0.82 : 1),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// 次操作按钮：表面填充 + 描边
struct SecondaryActionButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        SecondaryButtonBody(label: configuration.label, isPressed: configuration.isPressed)
    }

    private struct SecondaryButtonBody: View {
        let label: ButtonStyleConfiguration.Label
        let isPressed: Bool
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            label
                .font(Theme.font(14, .medium))
                .foregroundStyle(isEnabled ? Color.primary : Color.secondary.opacity(0.6))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Theme.surface,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Theme.border, lineWidth: 1))
                .opacity(isPressed ? 0.7 : 1)
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

// MARK: - 标签

/// 小号圆角标签，用于级别、题型等
struct Tag: View {
    let text: String
    var color: Color = Theme.accent

    var body: some View {
        Text(text)
            .font(Theme.font(12, .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

// MARK: - 勘误提示

/// 题目勘误说明的展示样式
struct ErrataNoteView: View {
    let note: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.bubble")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.warning)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text("勘误").font(Theme.label).foregroundStyle(Theme.warning)
                Text(note)
                    .font(Theme.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.warning.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.warning.opacity(0.35), lineWidth: 1))
    }
}

// MARK: - 空状态
/// 页面级空状态：图标 + 标题 + 说明
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(Theme.cardTitle)
            Text(message)
                .font(Theme.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 自动换行布局

/// 让子视图（如标签）自动换行的横向布局
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: maxWidth == .infinity ? max(0, x - spacing) : maxWidth,
                      height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
