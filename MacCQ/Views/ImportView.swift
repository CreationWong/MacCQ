//
//  ImportView.swift
//  MacCQ
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
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("导入题库")
                        .font(Theme.pageTitle)
                    Text("选择题库文件，题目会保存到本机，随时可以开始练习。")
                        .font(Theme.body)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("选择导入到哪个级别").font(Theme.sectionTitle)
                    HStack(spacing: 12) {
                        ForEach(Level.allCases) { l in
                            LevelChoiceCard(
                                level: l,
                                count: appState.count(for: l),
                                selected: level == l) {
                                    level = l
                                    message = nil
                                    errorMessage = nil
                                }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("题库文件").font(Theme.sectionTitle)

                    Button {
                        showImporter = true
                    } label: {
                        VStack(spacing: 10) {
                            Image(systemName: "tray.and.arrow.down")
                                .font(.system(size: 26, weight: .regular))
                                .foregroundStyle(Theme.accent)
                            Text("选择题库文件")
                                .font(Theme.font(15, .semibold))
                            Text("支持 PDF 或 TXT，文件名包含 A / B / C 类时会自动识别")
                                .font(Theme.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .background(
                            Theme.surfaceMuted,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    Theme.border,
                                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
                    }
                    .buttonStyle(.plain)

                    if let message {
                        statusLabel(message, systemImage: "checkmark.circle.fill", color: Theme.success)
                    }
                    if let errorMessage {
                        statusLabel(errorMessage, systemImage: "exclamationmark.circle.fill", color: Theme.danger)
                    }

                    Text("导入会替换该级别原有的题目，请确认文件正确后再导入。")
                        .font(Theme.caption)
                        .foregroundStyle(.secondary)
                }
                .card(padding: 20)

                if let report = appState.lastImport,
                   report.level == level.rawValue,
                   !report.unresolved.isEmpty {
                    unresolvedSection(report.unresolved)
                }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 28)
            .padding(.vertical, 32)
        }
        .pageBackground()
        .frame(minWidth: 560, minHeight: 480)
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
                    if report.valid == 0 {
                        message = nil
                        errorMessage = "没有从这个文件里识别到题目。请确认文件是文字版（可选中文字），且格式与题库一致。"
                    } else {
                        errorMessage = nil
                        var msg = "已导入「\(level.shortName)」，共 \(report.valid) 题"
                        if report.dropped > 0 {
                            msg += "，另有 \(report.dropped) 题需要人工确认"
                        }
                        message = msg
                    }
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
            .font(Theme.font(13))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func unresolvedSection(_ items: [UnresolvedQuestion]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("需要人工确认的题目").font(Theme.sectionTitle)
                Spacer()
                Tag(text: "\(items.count) 题", color: Theme.warning)
            }

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { offset, item in
                    if offset > 0 {
                        Divider().overlay(Theme.separator)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("第 \(item.number) 题")
                            .font(Theme.label)
                        Text(item.stem)
                            .font(Theme.body)
                            .lineLimit(3)
                        if !item.options.isEmpty {
                            Text(item.options.enumerated()
                                .map { "\(ExamEngine.optionLetter($0.offset)). \($0.element)" }
                                .joined(separator: "\n"))
                                .font(Theme.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(4)
                        }
                        Label(item.reason, systemImage: "exclamationmark.triangle.fill")
                            .font(Theme.caption)
                            .foregroundStyle(Theme.warning)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                }
            }

            Text("这些题目未能自动导入，通常是题干、选项或答案不完整。请检查原文件后重新导入。")
                .font(Theme.caption)
                .foregroundStyle(.secondary)
        }
        .card(padding: 20)
    }
}

/// 级别选择卡片
private struct LevelChoiceCard: View {
    let level: Level
    let count: Int
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(level.shortName)
                        .font(Theme.cardTitle)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? Theme.accent : Color.secondary.opacity(0.5))
                }
                Text(count > 0 ? "已有 \(count) 题" : "暂未导入")
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selected ? Theme.accent.opacity(0.09) : Theme.surface,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? Theme.accent : Theme.border, lineWidth: selected ? 1.5 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
