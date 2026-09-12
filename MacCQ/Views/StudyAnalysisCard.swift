//
//  StudyAnalysisCard.swift
//  MacCQ
//

import SwiftUI

/// 本地学习分析卡片：分题型正确率、薄弱主题与复习建议。
struct StudyAnalysisCard: View {
    let analysis: StudyAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundStyle(Theme.accent)
                Text("学习分析").font(Theme.sectionTitle)
            }

            if !analysis.byType.isEmpty {
                VStack(spacing: 10) {
                    ForEach(analysis.byType) { item in
                        HStack(spacing: 12) {
                            Text(item.type.label)
                                .font(Theme.label)
                                .frame(width: 58, alignment: .leading)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Theme.surfaceMuted)
                                    Capsule()
                                        .fill(item.accuracy >= 0.6 ? Theme.success : Theme.warning)
                                        .frame(width: max(4, geo.size.width * item.accuracy))
                                }
                            }
                            .frame(height: 8)
                            Text("\(item.correct)/\(item.total)")
                                .font(Theme.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 44, alignment: .trailing)
                        }
                    }
                }
            }

            if !analysis.weakTopics.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("薄弱主题").font(Theme.label).foregroundStyle(.secondary)
                    FlowLayout(spacing: 8) {
                        ForEach(analysis.weakTopics) { topic in
                            Tag(text: topic.title, color: Theme.warning)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 9) {
                Text("复习建议").font(Theme.label).foregroundStyle(.secondary)
                ForEach(Array(analysis.suggestions.enumerated()), id: \.offset) { _, suggestion in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .padding(.top, 2)
                        Text(suggestion)
                            .font(Theme.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .card(padding: 20)
    }
}
