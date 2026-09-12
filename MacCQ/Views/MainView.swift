//
//  MainView.swift
//  MacCQ
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
            .background(Theme.canvas)
        }
        .environment(appState)
        .tint(Theme.accent)
        .frame(minWidth: 1000, minHeight: 660)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            sidebarHeader
            Divider().overlay(Theme.separator)
            List(selection: $route) {
                Section {
                    NavigationItem(icon: "square.and.arrow.down", label: "导入题库")
                        .tag(Route.importBank)
                } header: {
                    Text("题库")
                }

                Section {
                    ForEach(Level.allCases) { level in
                        NavigationItem(icon: "book", label: level.shortName)
                            .tag(Route.practice(level))
                    }
                } header: {
                    Text("练习")
                }

                Section {
                    ForEach(Level.allCases) { level in
                        NavigationItem(icon: "doc.text", label: level.shortName)
                            .tag(Route.exam(level))
                    }
                } header: {
                    Text("模拟考试")
                }

                Section {
                    NavigationItem(icon: "checklist", label: "错题本")
                        .tag(Route.notebook)
                    NavigationItem(icon: "list.bullet.rectangle", label: "成绩记录")
                        .tag(Route.records)
                    NavigationItem(icon: "sparkles", label: "AI 助教")
                        .tag(Route.ai)
                    NavigationItem(icon: "gearshape", label: "设置")
                        .tag(Route.settings)
                } header: {
                    Text("其他")
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .navigationSplitViewColumnWidth(min: 210, ideal: 232)
    }

    private var sidebarHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text("MacCQ").font(Theme.font(15, .bold))
                Text("业余无线电操作证").font(Theme.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var detailView: some View {
        switch route ?? .importBank {
        case .importBank: ImportView()
        // Each level gets an independent view identity so @State from one bank
        // cannot leak into another when navigating between A/B/C.
        case .practice(let level): PracticeView(level: level).id(level)
        case .exam(let level): ExamHostView(level: level).id(level)
        case .notebook: NotebookView()
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
    }
}
