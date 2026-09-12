//
//  QuestionCardView.swift
//  MacCQ
//

import SwiftUI

/// 题目展示卡片：题干 + 可点选选项。练习与考试共用。
struct QuestionCardView: View {
    let question: ExamQuestion
    let revealed: Bool
    @Binding var selection: Set<Int>
    var isFavorite: Bool = false
    var onToggleFavorite: (() -> Void)? = nil
    var onErrata: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Tag(
                    text: question.type.label,
                    color: question.type == .single ? Theme.accent : Theme.warning)
                Spacer()
                if let onToggleFavorite {
                    Button {
                        onToggleFavorite()
                    } label: {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .font(.system(size: 13))
                            .foregroundStyle(isFavorite ? Theme.warning : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(isFavorite ? "取消收藏" : "收藏本题")
                }
                if let onErrata {
                    Button {
                        onErrata()
                    } label: {
                        Label("勘误", systemImage: "exclamationmark.bubble")
                            .font(Theme.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("标记题目或答案有误")
                }
                Text("第 \(question.bankOrder) 题")
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
            }

            Text(question.stem)
                .font(Theme.font(17, .medium))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)

            VStack(spacing: 8) {
                ForEach(question.options.indices, id: \.self) { i in
                    optionRow(i)
                }
            }
        }
        .padding(24)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1))
        .shadow(color: Theme.shadow, radius: 10, x: 0, y: 3)
    }

    private func optionRow(_ index: Int) -> some View {
        let isSelected = selection.contains(index)
        let isCorrect = question.correctIndices.contains(index)
        let showCorrect = revealed && isCorrect
        let showWrong = revealed && isSelected && !isCorrect

        return Button {
            guard !revealed else { return }
            if question.type == .multi {
                if isSelected { selection.remove(index) } else { selection.insert(index) }
            } else {
                selection = isSelected ? [] : [index]
            }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Text(ExamEngine.optionLetter(index))
                    .font(Theme.font(14, .semibold))
                    .foregroundStyle(letterForeground(selected: isSelected, correct: showCorrect, wrong: showWrong))
                    .frame(width: 26, height: 26)
                    .background(
                        letterBackground(selected: isSelected, correct: showCorrect, wrong: showWrong),
                        in: Circle())

                Text(question.options[index])
                    .font(Theme.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if showCorrect {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.success)
                } else if showWrong {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.danger)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                rowBackground(selected: isSelected, correct: showCorrect, wrong: showWrong),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        rowBorder(selected: isSelected, correct: showCorrect, wrong: showWrong),
                        lineWidth: isSelected || showCorrect || showWrong ? 1.5 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func rowBackground(selected: Bool, correct: Bool, wrong: Bool) -> Color {
        if correct { return Theme.success.opacity(0.10) }
        if wrong { return Theme.danger.opacity(0.10) }
        if selected { return Theme.accent.opacity(0.08) }
        return Theme.surfaceMuted
    }

    private func rowBorder(selected: Bool, correct: Bool, wrong: Bool) -> Color {
        if correct { return Theme.success }
        if wrong { return Theme.danger }
        if selected { return Theme.accent }
        return Theme.border
    }

    private func letterBackground(selected: Bool, correct: Bool, wrong: Bool) -> Color {
        if correct { return Theme.success }
        if wrong { return Theme.danger }
        if selected { return Theme.accent }
        return Theme.border.opacity(0.55)
    }

    private func letterForeground(selected: Bool, correct: Bool, wrong: Bool) -> Color {
        (correct || wrong || selected) ? .white : .secondary
    }
}
