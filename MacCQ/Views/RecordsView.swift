//
//  RecordsView.swift
//  MacCQ
//

import SwiftUI

struct RecordsView: View {
    @Environment(AppState.self) private var appState
    @State private var showClearConfirm = false
    @State private var showTraining = false

    var body: some View {
        Group {
            if appState.records.isEmpty {
                EmptyStateView(
                    icon: "list.bullet.rectangle",
                    title: "暂无成绩记录",
                    message: "完成一次模拟考试后，成绩会显示在这里。")
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        summaryCard
                        LazyVStack(spacing: 10) {
                            ForEach(appState.records) { r in
                                recordRow(r)
                            }
                        }
                    }
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 28)
                }
            }
        }
        .pageBackground()
        .navigationTitle("成绩记录")
        .toolbar {
            if !appState.records.isEmpty {
                Button(role: .destructive) { showClearConfirm = true } label: {
                    Label("清空", systemImage: "trash")
                }
            }
        }
        .confirmationDialog("确定清空全部成绩记录吗？", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("清空", role: .destructive) {
                DatabaseManager.shared.clearRecords()
                appState.refresh()
            }
            Button("取消", role: .cancel) {}
        }
        .sheet(isPresented: $showTraining) {
            TargetedTrainingView(
                initialTopics: Array(recentWeakTopics.prefix(6)),
                showsCloseButton: true)
        }
        .onAppear { appState.refresh() }
    }

    /// 从近期考试记录中汇总薄弱主题
    private var recentWeakTopics: [String] {
        var counts: [String: Int] = [:]
        for record in appState.records {
            for topic in record.weakTopics {
                counts[topic, default: 0] += 1
            }
        }
        return counts
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .map(\.key)
    }

    private var summaryCard: some View {
        let exams = appState.records.filter { $0.isExam }
        let passed = exams.filter { $0.passed }.count
        let totalCorrect = exams.reduce(0) { $0 + $1.correct }
        let totalQuestions = exams.reduce(0) { $0 + $1.total }
        let passRate = exams.isEmpty ? 0 : Double(passed) / Double(exams.count)
        let accuracy = totalQuestions == 0 ? 0 : Double(totalCorrect) / Double(totalQuestions)

        let advice: String
        if exams.isEmpty {
            advice = "完成模拟考试后，这里会显示整体趋势。"
        } else if passRate >= 0.8 {
            advice = "近期状态不错，保持练习频率，注意别在简单题上失分。"
        } else if passRate >= 0.5 {
            advice = "已经有一定基础，重点复习错得较多的知识主题，合格率会明显提升。"
        } else {
            advice = "合格率还有较大提升空间，建议针对薄弱主题使用 AI 专项训练，再多做模拟题。"
        }

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 0) {
                summaryStat("模拟考试", "\(exams.count) 次")
                Divider().frame(height: 32).overlay(Theme.separator)
                summaryStat("合格率", String(format: "%.0f%%", passRate * 100))
                Divider().frame(height: 32).overlay(Theme.separator)
                summaryStat("平均正确率", String(format: "%.0f%%", accuracy * 100))
            }
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 2)
                Text(advice)
                    .font(Theme.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button {
                    showTraining = true
                } label: {
                    Label("针对薄弱点专项训练", systemImage: "wand.and.stars")
                }
                .buttonStyle(SecondaryActionButton())
            }
        }
        .card(padding: 20)
    }

    private func summaryStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 5) {
            Text(value).font(Theme.font(19, .semibold))
            Text(label).font(Theme.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func recordRow(_ r: ExamRecord) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(r.date, format: .dateTime.year().month().day().hour().minute())
                    .font(Theme.font(15, .semibold))
                HStack(spacing: 8) {
                    Tag(text: r.level + " 类")
                    Text(r.isExam ? "模拟考试" : "练习")
                        .font(Theme.caption)
                        .foregroundStyle(.secondary)
                    if r.isExam {
                        Text(r.passed ? "合格" : "不合格")
                            .font(Theme.caption)
                            .foregroundStyle(r.passed ? Theme.success : Theme.danger)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(r.correct) / \(r.total)")
                    .font(Theme.font(18, .semibold))
                Text("用时 \(r.durationSeconds / 60) 分 \(r.durationSeconds % 60) 秒")
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .card(padding: 16)
    }
}
