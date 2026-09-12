//
//  QuestionReviewSheet.swift
//  MacCQ
//

import SwiftUI

/// 复习一组题目（错题本 / 收藏）：可查看答案、收藏、勘误。
struct QuestionReviewSheet: View {
    let questions: [ExamQuestion]
    let title: String

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var index = 0
    @State private var selection: Set<Int> = []
    @State private var revealed = false
    @State private var errataQuestion: ExamQuestion?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.separator)

            if questions.isEmpty {
                EmptyStateView(icon: "tray", title: "没有可复习的题目", message: "先去练习或考试中积累题目吧。")
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        QuestionCardView(
                            question: questions[index],
                            revealed: revealed,
                            selection: $selection,
                            isFavorite: appState.isFavorite(questions[index].id),
                            onToggleFavorite: { appState.toggleFavorite(questions[index].id) },
                            onErrata: errataAction(for: questions[index]))
                        if let note = appState.note(for: questions[index].id), !note.isEmpty {
                            noteCard(note)
                        }
                        if revealed, wrongQuestionIds.contains(questions[index].id) {
                            Button {
                                appState.removeWrongQuestion(questions[index].id)
                            } label: {
                                Label("已掌握，移出错题本", systemImage: "checkmark.circle")
                            }
                            .buttonStyle(SecondaryActionButton())
                        }
                    }
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                    .padding(24)
                }
            }

            Divider().overlay(Theme.separator)
            footer
        }
        .frame(width: 640, height: 600)
        .background(Theme.canvas)
        .sheet(item: $errataQuestion) { ErrataSheet(question: $0) }
    }

    private var wrongQuestionIds: Set<Int64> {
        Set(appState.wrongQuestionIds)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "book.closed")
                .foregroundStyle(Theme.accent)
            Text(title).font(Theme.cardTitle)
            if !questions.isEmpty {
                Text("第 \(index + 1) / \(questions.count) 题")
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var footer: some View {
        HStack {
            Button {
                step(-1)
            } label: {
                Label("上一题", systemImage: "chevron.left")
            }
            .buttonStyle(SecondaryActionButton())
            .disabled(index == 0)

            Spacer()

            if !questions.isEmpty {
                if !revealed {
                    Button {
                        revealed = true
                    } label: {
                        Label("查看答案", systemImage: "eye")
                    }
                    .buttonStyle(PrimaryActionButton())
                } else {
                    Button {
                        step(1)
                    } label: {
                        Label("下一题", systemImage: "chevron.right")
                    }
                    .buttonStyle(PrimaryActionButton())
                    .disabled(index == questions.count - 1)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func noteCard(_ note: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.bubble")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.warning)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text("勘误").font(Theme.label).foregroundStyle(Theme.warning)
                Text(note).font(Theme.body).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.warning.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.warning.opacity(0.35), lineWidth: 1))
    }

    private func errataAction(for question: ExamQuestion) -> (() -> Void)? {
        guard question.id > 0 else { return nil }
        return { errataQuestion = question }
    }

    private func step(_ delta: Int) {
        let next = min(max(0, index + delta), max(0, questions.count - 1))
        guard next != index else { return }
        index = next
        selection = []
        revealed = false
    }
}
