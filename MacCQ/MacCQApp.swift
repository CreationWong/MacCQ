//
//  MacCQApp.swift
//  MacCQ
//

import SwiftUI

@main
struct MacCQApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .windowResizability(.contentMinSize)
        .commands {
            SidebarCommands()
        }
    }
}
