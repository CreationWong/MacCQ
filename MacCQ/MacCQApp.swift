//
//  MacCQApp.swift
//  MacCQ
//

import SwiftUI

@main
struct MacCQApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
        .windowResizability(.contentMinSize)
        .commands {
            SidebarCommands()
        }
    }
}
