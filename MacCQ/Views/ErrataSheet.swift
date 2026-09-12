//
//  ErrataSheet.swift
//  MacCQ
//

import SwiftUI

/// 题目勘误：记录用户发现的题目、答案或解析问题（仅保存在本机）。
struct ErrataSheet: View {
    let question: ExamQuestion

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.bubble")
                    .foregroundStyle(Theme.warning)
                Text("题目勘误").font(Theme.cardTitle)
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

            Divider().overlay(Theme.separator)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(question.stem)
                            .font(Theme.font(14, .medium))
                            .fixedSize(horizontal: false, vertical: true)
                        if !question.options.isEmpty {
                            Text(question.options.enumerated()
                                .map { "\(ExamEngine.optionLetter($0.offset)). \($0.element)" }
                                .joined(separator: "\n"))
                                .font(Theme.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("勘误说明").font(Theme.label)
                        TextEditor(text: $text)
                            .font(Theme.body)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(Theme.surfaceMuted, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Theme.border, lineWidth: 1))
                        Text("例如：正确答案有误、题干或选项文字识别错误、解析不准确等。勘误只保存在本机。")
                            .font(Theme.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }

            Divider().overlay(Theme.separator)

            HStack {
                if appState.note(for: question.id) != nil {
                    Button("删除勘误", role: .destructive) {
                        appState.saveNote("", for: question.id)
                        dismiss()
                    }
                    .buttonStyle(SecondaryActionButton())
                }
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(SecondaryActionButton())
                Button("保存") {
                    appState.saveNote(text, for: question.id)
                    dismiss()
                }
                .buttonStyle(PrimaryActionButton())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 520, height: 460)
        .background(Theme.canvas)
        .onAppear { text = appState.note(for: question.id) ?? "" }
    }
}
