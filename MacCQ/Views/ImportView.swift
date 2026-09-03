//
//  ImportView.swift
//  MacCQ
//
//  Created by CreationWong on 2026/9/2.
//

import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(AppState.self) private var appState
    @State private var level: Level = .a
    @State private var showImporter = false
    @State private var message: String?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("导入题库")
                        .font(MacDesign.title)
                    Text("按级别导入 PDF 或 TXT 题库，导入后会替换该级别已有题目。")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 14) {
                Picker("导入级别", selection: $level) {
                    ForEach(Level.allCases) { l in
                        Text("\(l.name)（\(l.questionCount)题）").tag(l)
                    }
                }
                HStack {
                    Label("当前题库", systemImage: "books.vertical")
                    Spacer()
                    Text("\(appState.count(for: level)) 题")
                        .font(.system(.headline, design: .rounded))
                }
                }
                .padding(18)
                .glassCard(cornerRadius: 16)

                VStack(alignment: .leading, spacing: 14) {
                    Text("导入文件")
                        .font(MacDesign.cardTitle)
                    Button {
                        showImporter = true
                    } label: {
                        Label("选择 PDF / TXT 题库文件", systemImage: "doc.badge.plus")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MacDesign.accentTint)

                    if let message {
                        statusLabel(message, systemImage: "checkmark.circle.fill", color: .green)
                    }
                    if let errorMessage {
                        statusLabel(errorMessage, systemImage: "xmark.octagon.fill", color: .red)
                    }
                }
                .padding(18)
                .glassCard(cornerRadius: 16)

                if let report = appState.lastImport,
                   report.level == level.rawValue,
                   !report.unresolved.isEmpty {
                    unresolvedSection(report.unresolved)
                }

                Text("支持 PDF 与 TXT 文本题库。选择文件时会按文件名（如「A类题库」）自动匹配级别，也可手动修改。扫描件 PDF 需先做 OCR。")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
        .frame(minWidth: 560, minHeight: 480)
        .scrollContentBackground(.hidden)
        .navigationTitle("导入题库")
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.pdf, .plainText], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                // 依据文件名自动匹配级别，避免导入到错误的级别
                if let detected = BankImporter.detectLevel(from: url) {
                    level = detected
                }
                do {
                    let report = try appState.importBank(url: url, level: level)
                    errorMessage = nil
                    var msg = "已将「\(level.name)」导入 \(report.valid) 题"
                    if report.dropped > 0 {
                        msg += "（\(report.dropped) 题未自动导入，请人工确认）"
                    }
                    message = msg
                } catch {
                    message = nil
                    errorMessage = "导入失败：\(error.localizedDescription)"
                }
            case .failure(let error):
                errorMessage = "选择文件失败：\(error.localizedDescription)"
            }
        }
    }

    private func statusLabel(_ text: String, systemImage: String, color: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(.callout, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPill(cornerRadius: 10)
    }

    @ViewBuilder
    private func unresolvedSection(_ items: [UnresolvedQuestion]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("需要人工确认", systemImage: "person.crop.circle.badge.questionmark")
                    .foregroundStyle(.orange)
                Spacer()
                Text("\(items.count) 题")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.orange)
            }
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text("第 \(item.number) 题")
                        .font(.system(.headline, design: .rounded))
                    Text(item.stem)
                        .font(.system(.body, design: .rounded))
                        .lineLimit(4)
                    if !item.options.isEmpty {
                        Text(item.options.enumerated().map { "\(ExamEngine.optionLetter($0.offset)). \($0.element)" }.joined(separator: "\n"))
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Label(item.reason, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(.orange)
                }
                .padding(.vertical, 6)
            }
            Text("以上题目未自动导入，请检查原文件中的题干、选项和答案后再重新导入。")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .glassCard(cornerRadius: 16)
    }
}
