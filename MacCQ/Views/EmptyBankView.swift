//
//  EmptyBankView.swift
//  MacCQ
//

import SwiftUI

struct EmptyBankView: View {
    let level: Level
    let hint: String

    var body: some View {
        EmptyStateView(
            icon: "tray",
            title: "\(level.name)题库为空",
            message: hint)
            .pageBackground()
    }
}
