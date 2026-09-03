//
//  RecordsView.swift
//  MacCQ
//
//  Created by CreationWong on 2026/9/2.
//

import SwiftUI

struct RecordsView: View {
    @Environment(AppState.self) private var appState
    @State private var showClearConfirm = false

    var body: some View {
        Group {
            if appState.records.isEmpty {
                ContentUnavailableView("暂无成绩记录", systemImage: "doc.text",
                                       description: Text("完成一次模拟考试后会在此显示。"))
            } else {
                List {
                    ForEach(appState.records) { r in
                        recordRow(r)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("成绩记录")
        .toolbar {
            if !appState.records.isEmpty {
                Button(role: .destructive) { showClearConfirm = true } label: {
                    Label("清空", systemImage: "trash")
                }
            }
        }
        .confirmationDialog("确认清空全部成绩记录？", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("清空", role: .destructive) {
                DatabaseManager.shared.clearRecords()
                appState.refresh()
            }
            Button("取消", role: .cancel) {}
        }
        .onAppear { appState.refresh() }
    }

    private func recordRow(_ r: ExamRecord) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(r.date, format: .dateTime.year().month().day().hour().minute())
                    .font(.headline)
                HStack(spacing: 8) {
                    Text("\(r.level)类")
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.blue.opacity(0.12), in: Capsule())
                    Text(r.isExam ? "模拟考试" : "练习")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if r.isExam {
                        Label(r.passed ? "合格" : "不合格", systemImage: r.passed ? "checkmark" : "xmark")
                            .font(.caption)
                            .foregroundStyle(r.passed ? .green : .red)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("\(r.correct) / \(r.total)")
                    .font(.title3.weight(.semibold))
                Text("用时 \(r.durationSeconds / 60) 分 \(r.durationSeconds % 60) 秒")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
