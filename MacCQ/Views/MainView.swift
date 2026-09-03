//
//  MainView.swift
//  MacCQ
//
//  Created by CreationWong on 2026/9/2.
//

import SwiftUI

struct MainView: View {
    @State private var route: Route? = .importBank
    @State private var appState = AppState()

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            NavigationStack {
                detailView
            }
            .background(MacDesign.background)
        }
        .containerBackground(MacDesign.windowGradient, for: .window)
        .environment(appState)
        .frame(minWidth: 980, minHeight: 640)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            sidebarHeader
            List(selection: $route) {
                Section {
                    NavigationItem(icon: "square.and.arrow.down", label: "导入题库")
                        .tag(Route.importBank)
                } header: {
                    Text("题库")
                }

                Section {
                    ForEach(Level.allCases) { level in
                        NavigationItem(icon: "book", label: "\(level.name)")
                            .tag(Route.practice(level))
                    }
                } header: {
                    Text("练习")
                }

                Section {
                    ForEach(Level.allCases) { level in
                        NavigationItem(icon: "doc.text", label: "\(level.name)")
                            .tag(Route.exam(level))
                    }
                } header: {
                    Text("模拟考试")
                }

                Section {
                    NavigationItem(icon: "list.bullet.rectangle", label: "成绩记录")
                        .tag(Route.records)
                    NavigationItem(icon: "bubble.left.and.bubble.right", label: "AI 答疑")
                        .tag(Route.ai)
                    NavigationItem(icon: "gearshape", label: "设置")
                        .tag(Route.settings)
                } header: {
                    Text("记录与帮助")
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .navigationSplitViewColumnWidth(min: 210, ideal: 240)
            .tint(MacDesign.accentTint)
        }
    }

    private var sidebarHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "text.book.closed.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(LinearGradient(colors: [Color.blue, Color.indigo], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 1) {
                Text("MacCQ").font(.system(.headline, design: .rounded, weight: .bold))
                Text("操作资格练习与模拟")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var detailView: some View {
        switch route ?? .importBank {
        case .importBank: ImportView()
        // Each level gets an independent view identity so @State from one bank
        // cannot leak into another when navigating between A/B/C.
        case .practice(let level): PracticeView(level: level).id(level)
        case .exam(let level): ExamHostView(level: level).id(level)
        case .records: RecordsView()
        case .ai: AIView()
        case .settings: SettingsView()
        }
    }
}

/// 侧边栏条目
private struct NavigationItem: View {
    let icon: String
    let label: String

    var body: some View {
        Label(label, systemImage: icon)
            .font(.system(.body, design: .rounded))
    }
}
