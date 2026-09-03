//
//  ExamResultView.swift
//  MacCQ
//
//  Created by CreationWong on 2026/9/2.
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

    private var passed: Bool { level.passed(correctCount: correct) }

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: passed ? "checkmark.seal.fill" : "xmark.seal.fill")
                .font(.system(size: 46))
                .foregroundStyle(passed ? .green : .red)
            Text(passed ? "恭喜，考试合格" : "很遗憾，考试未合格")
                .font(.title.bold())

            HStack(spacing: 14) {
                stat("答题数", "\(paper.count)")
                stat("答对", "\(correct)")
                stat("答错", "\(wrong.count)")
                stat("正确率", String(format: "%.0f%%", paper.count == 0 ? 0 : Double(correct) / Double(paper.count) * 100))
                stat("用时", timeText(duration))
            }
            .glassCard(cornerRadius: 20)
            .padding(.horizontal, 28)

            if !wrong.isEmpty {
                Divider()
                wrongReview
            } else {
                Text("全部答对，无错题。")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 14) {
                Button("再次考试") { onRestart() }
                    .buttonStyle(.borderedProminent)
                    .tint(MacDesign.accentTint)
                Button("查看成绩记录") { }
                    .disabled(true)
            }
            .padding(.top, 8)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var wrongReview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("错题回顾").font(.headline)
                ForEach(wrong, id: \.self) { i in
                    let q = paper[i]
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(i + 1)、\(q.stem)")
                            .fontWeight(.medium)
                        Text("你的答案：\(letters(answers[i] ?? []))")
                            .foregroundStyle(.red)
                        Text("正确答案：\(letters(Set(q.correctIndices)))")
                            .foregroundStyle(.green)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .frame(maxWidth: 640)
        }
        .frame(maxHeight: 260)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(.title2, design: .rounded, weight: .semibold))
        }
        .frame(minWidth: 76)
    }

    private func letters(_ set: Set<Int>) -> String {
        let sorted = set.sorted()
        return sorted.map { ExamEngine.optionLetter($0) }.joined(separator: " ")
    }

    private func letters(_ arr: [Int]) -> String {
        let sorted = arr.sorted()
        return sorted.map { ExamEngine.optionLetter($0) }.joined(separator: " ")
    }

    private func timeText(_ s: Int) -> String {
        String(format: "%02d:%02d", s / 60, s % 60)
    }
}
