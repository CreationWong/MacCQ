//
//  MainView.swift
//  MacCQ
//

import SwiftUI

struct MainView: View {
    @State private var route: Route? = .importBank
    @State private var appState = AppState()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .toolbar(removing: .sidebarToggle)
        } detail: {
            NavigationStack {
                detailView
            }
            .background(Theme.canvas)
            .toolbar(removing: .sidebarToggle)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button {
                        withAnimation {
                            columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
                        }
                    } label: {
                        Image(systemName: "sidebar.leading")
                    }
                    .help(columnVisibility == .detailOnly ? "显示侧边栏" : "隐藏侧边栏")
                }
            }
        }
        .background(ToolbarChromeFix())
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

    private var detailView: some View {
        ZStack {
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
}

private struct ToolbarChromeFix: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { ChromeFixView() }
    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? ChromeFixView)?.install()
    }
}

private final class ChromeFixView: NSView {
    private weak var observedWindow: NSWindow?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        install()
    }

    func install() {
        guard let window else { return }
        apply(to: window)
        guard observedWindow !== window else { return }
        if observedWindow != nil {
            NotificationCenter.default.removeObserver(
                self, name: NSWindow.didUpdateNotification, object: observedWindow)
        }
        observedWindow = window
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidUpdate),
            name: NSWindow.didUpdateNotification,
            object: window)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func windowDidUpdate(_ notification: Notification) {
        guard let window else { return }
        apply(to: window)
    }

    private func apply(to window: NSWindow) {
        if let toolbar = window.toolbar {
            if toolbar.displayMode != .iconOnly {
                toolbar.displayMode = .iconOnly
            }
            toolbar.allowsDisplayModeCustomization = false
        }
        guard let themeFrame = window.contentView?.superview else { return }
        for subview in themeFrame.subviews {
            let name = NSStringFromClass(type(of: subview))
            if name.contains("Titlebar") || name.contains("Toolbar") {
                hideOverflow(in: subview)
            }
        }
    }

    private func hideOverflow(in view: NSView) {
        let name = NSStringFromClass(type(of: view))
        if name.contains("ClippedItemsIndicator") || name.contains("ToolbarOverflow") {
            if !view.isHidden { view.isHidden = true }
            if view.alphaValue != 0 { view.alphaValue = 0 }
            return
        }
        if let button = view as? NSButton {
            let title = button.title
            if title == "»" || title == "››" {
                if !button.isHidden { button.isHidden = true }
                if button.alphaValue != 0 { button.alphaValue = 0 }
                return
            }
        }
        for subview in view.subviews {
            hideOverflow(in: subview)
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
