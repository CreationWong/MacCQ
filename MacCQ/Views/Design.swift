//
//  Design.swift
//  MacCQ
//
//  Created by CreationWong on 2026/9/2.
//

import SwiftUI

/// macOS 液态玻璃设计系统
enum MacDesign {
    static let accentTint = Color(red: 0.20, green: 0.47, blue: 0.96)

    // 窗口背景：柔和渐变 + 顶部辉光
    static let windowGradient = LinearGradient(
        colors: [
            Color(red: 0.99, green: 0.99, blue: 1.00),
            Color(red: 0.93, green: 0.96, blue: 1.00),
            Color(red: 0.88, green: 0.93, blue: 0.99),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing)

    static let glow = RadialGradient(
        colors: [Color.white.opacity(0.9), Color.clear],
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
                    .strokeBorder(.white.opacity(0.45), lineWidth: 0.6)
            )
    }
}

/// 玻璃描边胶囊（按钮/徽章）
struct GlassPill: ViewModifier {
    var cornerRadius: CGFloat
    init(cornerRadius: CGFloat = 10) { self.cornerRadius = cornerRadius }

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(.white.opacity(0.35), lineWidth: 0.5)
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }

    func glassPill(cornerRadius: CGFloat = 10) -> some View {
        modifier(GlassPill(cornerRadius: cornerRadius))
    }
}
