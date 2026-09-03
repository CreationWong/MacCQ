//
//  QuestionCardView.swift
//  MacCQ
//
//  Created by CreationWong on 2026/9/2.
//

import SwiftUI

/// 题目展示卡片：题干 + 可点选选项。练习与考试共用。
struct QuestionCardView: View {
    let question: ExamQuestion
    let revealed: Bool
    @Binding var selection: Set<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                typeBadge
                Spacer()
                Text("题库序号 \(question.bankOrder)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(question.stem)
                .font(.system(.title3, design: .rounded, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 2)

            VStack(spacing: 10) {
                ForEach(question.options.indices, id: \.self) { i in
                    optionRow(i)
                }
            }
        }
        .padding(22)
        .glassCard(cornerRadius: 22)
    }

    private var typeBadge: some View {
        Text(question.type.label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                LinearGradient(
                    colors: question.type == .single
                        ? [Color.blue, Color.indigo]
                        : [Color.orange, Color.pink],
                    startPoint: .top, endPoint: .bottom),
                in: Capsule())
    }

    private func optionRow(_ index: Int) -> some View {
        let isSelected = selection.contains(index)
        let isCorrect = question.correctIndices.contains(index)
        let revealCorrect = revealed && isCorrect
        let revealWrong = revealed && isSelected && !isCorrect

        return Button {
            if question.type == .multi {
                if isSelected { selection.remove(index) } else { selection.insert(index) }
            } else {
                selection = isSelected ? [] : [index]
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(ExamEngine.optionLetter(index))
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(letterFill(isSelected: isSelected, correct: revealCorrect, wrong: revealWrong), in: Circle())
                Text(question.options[index])
                    .font(.system(.body, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(letterFill(isSelected: isSelected, correct: revealCorrect, wrong: revealWrong))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground(isSelected: isSelected, correct: revealCorrect, wrong: revealWrong))
        }
        .buttonStyle(.plain)
    }

    private func rowBackground(isSelected: Bool, correct: Bool, wrong: Bool) -> some View {
        RoundedRectangle(cornerRadius: 13)
            .glassEffect(.regular.interactive().tint(rowTint(isSelected: isSelected, correct: correct, wrong: wrong)), in: .rect(cornerRadius: 13))
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(rowBorder(isSelected: isSelected, correct: correct, wrong: wrong), lineWidth: 1))
    }

    private func rowTint(isSelected: Bool, correct: Bool, wrong: Bool) -> Color? {
        if correct { return Color.green.opacity(0.30) }
        if wrong { return Color.red.opacity(0.30) }
        if isSelected { return MacDesign.accentTint.opacity(0.28) }
        return nil
    }

    private func rowBorder(isSelected: Bool, correct: Bool, wrong: Bool) -> Color {
        if correct { return Color.green.opacity(0.55) }
        if wrong { return Color.red.opacity(0.55) }
        if isSelected { return MacDesign.accentTint.opacity(0.6) }
        return MacDesign.glassBorder
    }

    private func letterFill(isSelected: Bool, correct: Bool, wrong: Bool) -> Color {
        if correct { return .green }
        if wrong { return .red }
        if isSelected { return MacDesign.accentTint }
        return Color.gray.opacity(0.6)
    }
}
