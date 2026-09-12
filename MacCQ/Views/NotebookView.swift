//
//  NotebookView.swift
//  MacCQ
//

import SwiftUI

/// 错题本与收藏：集中查看、复习和整理做错或收藏的题目。
struct NotebookView: View {
    @Environment(AppState.self) private var appState

    private enum Tab: String, CaseIterable, Identifiable {
        case wrong = "错题本"
        case favorite = "收藏"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .wrong
    @State private var questions: [Question] = []
    @State private var expanded: Set<Int64> = []
    @State private var showReview = false
    @State private var reviewQuestions: [ExamQuestion] = []
    @State private var errataQuestion: ExamQuestion?
    @State private var showClearConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 320)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)

            Divider().overlay(Theme.separator)

            if questions.isEmpty {
                EmptyStateView(
                    icon: tab == .wrong ? "xmark.circle" : "star",
                    title: tab == .wrong ? "错题本是空的" : "还没有收藏题目",
                    message: tab == .wrong
                        ? "练习或考试中做错的题目会自动收集到这里。"
                        : "在练习时点击题目右上角的星标即可收藏。")
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(questions) { q in
                            row(q)
                        }
                    }
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 24)
                }
            }
        }
        .pageBackground()
        .navigationTitle("错题本与收藏")
        .toolbar {
            if !questions.isEmpty {
                ToolbarItemGroup {
                    Button {
                        startReview()
                    } label: {
                        Label("复习全部", systemImage: "play.circle")
                    }
                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Label("清空", systemImage: "trash")
                    }
                }
            }
        }
        .confirmationDialog(
            tab == .wrong ? "确定清空错题本吗？" : "确定清空收藏吗？",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("清空", role: .destructive) {
                if tab == .wrong {
                    appState.clearWrongQuestions()
                } else {
                    appState.clearFavorites()
                }
                reload()
            }
            Button("取消", role: .cancel) {}
        }
        .sheet(isPresented: $showReview) {
            QuestionReviewSheet(questions: reviewQuestions, title: tab.rawValue)
        }
        .sheet(item: $errataQuestion) { question in
            ErrataSheet(question: question)
        }
        .onAppear { reload() }
        .onChange(of: tab) { reload() }
    }

    private func row(_ q: Question) -> some View {
        let isExpanded = expanded.contains(q.id)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Tag(text: q.level + " 类")
                Tag(text: q.type.shortLabel, color: q.type == .single ? Theme.accent : Theme.warning)
                Spacer()
                Button {
                    appState.toggleFavorite(q.id)
                    if tab == .favorite {
                        questions.removeAll { $0.id == q.id }
                    }
                } label: {
                    Image(systemName: appState.isFavorite(q.id) ? "star.fill" : "star")
                        .font(.system(size: 13))
                        .foregroundStyle(appState.isFavorite(q.id) ? Theme.warning : Color.secondary)
                }
                .buttonStyle(.plain)
                .help(appState.isFavorite(q.id) ? "取消收藏" : "收藏本题")

                Button {
                    remove(q)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(tab == .wrong ? "移出错题本" : "取消收藏")
            }

            Text(q.stem)
                .font(Theme.font(14, .medium))
                .fixedSize(horizontal: false, vertical: true)

            if isExpanded {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(q.options.indices, id: \.self) { i in
                        let correct = q.correct.contains(i)
                        HStack(alignment: .top, spacing: 7) {
                            Image(systemName: correct ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 11))
                                .foregroundStyle(correct ? Theme.success : Color.secondary.opacity(0.5))
                                .padding(.top, 1)
                            Text("\(ExamEngine.optionLetter(i)). \(q.options[i])")
                                .font(Theme.caption)
                                .foregroundStyle(correct ? Theme.success : .secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 2)

                if let note = appState.note(for: q.id), !note.isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.bubble")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.warning)
                            .padding(.top, 1)
                        Text(note)
                            .font(Theme.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                Button(isExpanded ? "收起" : "查看答案") {
                    if isExpanded {
                        expanded.remove(q.id)
                    } else {
                        expanded.insert(q.id)
                    }
                }
                .font(Theme.caption)
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accent)

                Button("勘误") {
                    errataQuestion = examQuestion(q)
                }
                .font(Theme.caption)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .card(padding: 16)
    }

    private func examQuestion(_ q: Question) -> ExamQuestion {
        ExamQuestion(id: q.id, level: q.level, type: q.type, stem: q.stem,
                     options: q.options, correctIndices: q.correct, bankOrder: q.bankOrder)
    }

    private func remove(_ q: Question) {        if tab == .wrong {
            appState.removeWrongQuestion(q.id)
        } else {
            appState.toggleFavorite(q.id)
        }
        questions.removeAll { $0.id == q.id }
    }

    private func startReview() {
        reviewQuestions = questions.map(examQuestion)
        showReview = true
    }

    private func reload() {
        let ids = tab == .wrong ? appState.wrongQuestionIds : appState.favoriteQuestionIds
        questions = appState.loadQuestions(ids: ids)
        expanded = []
    }
}
