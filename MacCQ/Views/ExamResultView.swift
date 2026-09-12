//
//  ExamResultView.swift
//  MacCQ
//

import SwiftUI

struct ExamResultView: View {
    let level: Level
    let paper: [ExamQuestion]
    let answers: [Int: Set<Int>]
    let correct: Int
    let wrong: [Int]
    let duration: Int
    let onRestart: () -> Void

    @State private var showAIReport = false
    @State private var showTraining = false

    private var passed: Bool { level.passed(correctCount: correct) }
    private var analysis: StudyAnalysis { StudyAnalyzer.analyze(paper: paper, answers: answers) }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 12) {
                    Image(systemName: passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 52, weight: .regular))
                        .foregroundStyle(passed ? Theme.success : Theme.danger)
                    Text(passed ? "考试合格" : "考试未合格")
                        .font(Theme.pageTitle)
                    Text(passed ? "恭喜你通过了本次模拟考试。" : "继续练习，下次一定可以。")
                        .font(Theme.body)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 0) {
                    stat("答题", "\(paper.count)")
                    statDivider
                    stat("答对", "\(correct)")
                    statDivider
                    stat("答错", "\(wrong.count)")
                    statDivider
                    stat("正确率", String(format: "%.0f%%", paper.count == 0 ? 0 : Double(correct) / Double(paper.count) * 100))
                    statDivider
                    stat("用时", timeText(duration))
                }
                .card(padding: 18)
                .frame(maxWidth: 640)

                StudyAnalysisCard(analysis: analysis)
                    .frame(maxWidth: 640, alignment: .leading)

                if wrong.isEmpty {
                    Text("全部答对，没有错题。")
                        .font(Theme.body)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    wrongReview
                }

                HStack(spacing: 12) {
                    Button("再考一次") { onRestart() }
                        .buttonStyle(PrimaryActionButton())
                    Button {
                        showAIReport = true
                    } label: {
                        Label("AI 深度分析", systemImage: "sparkles")
                    }
                    .buttonStyle(SecondaryActionButton())
                    Button {
                        showTraining = true
                    } label: {
                        Label("专项训练", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(SecondaryActionButton())
                }
            }
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
            .padding(32)
        }
        .sheet(isPresented: $showAIReport) {
            AIReportSheet(
                title: "AI 考试分析",
                systemPrompt: AITutor.analystSystem,
                userPrompt: AITutor.examPrompt(analysis: analysis))
        }
        .sheet(isPresented: $showTraining) {
            TargetedTrainingView(
                fixedLevel: level,
                initialTopics: analysis.weakTopics.map(\.title),
                showsCloseButton: true)
        }
    }

    // MARK: - 错题回顾

    private var wrongReview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("错题回顾").font(Theme.sectionTitle)
                Spacer()
                Text("已自动加入错题本")
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(wrong.enumerated()), id: \.element) { offset, i in
                    if offset > 0 {
                        Divider().overlay(Theme.separator)
                    }
                    let q = paper[i]
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(i + 1)、\(q.stem)")
                            .font(Theme.font(14, .medium))
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 16) {
                            Label("你的答案：\(letters(answers[i] ?? []))", systemImage: "xmark")
                                .foregroundStyle(Theme.danger)
                            Label("正确答案：\(letters(Set(q.correctIndices)))", systemImage: "checkmark")
                                .foregroundStyle(Theme.success)
                        }
                        .font(Theme.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                }
            }
        }
        .card(padding: 20)
        .frame(maxWidth: 640)
    }

    private var statDivider: some View {
        Divider().frame(height: 32).overlay(Theme.separator)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 5) {
            Text(value).font(Theme.font(19, .semibold))
            Text(label).font(Theme.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func letters(_ set: Set<Int>) -> String {
        set.sorted().map { ExamEngine.optionLetter($0) }.joined(separator: " ")
    }

    private func letters(_ arr: [Int]) -> String {
        arr.sorted().map { ExamEngine.optionLetter($0) }.joined(separator: " ")
    }

    private func timeText(_ s: Int) -> String {
        String(format: "%02d:%02d", s / 60, s % 60)
    }
}
