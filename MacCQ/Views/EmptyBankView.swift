//
//  EmptyBankView.swift
//  MacCQ
//
//  Created by CreationWong on 2026/9/2.
//

import SwiftUI

struct EmptyBankView: View {
    let level: Level
    let hint: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
                .padding(24)
                .glassPill(cornerRadius: 24)
            Text("\(level.name) 题库为空")
                .font(.system(.title3, design: .rounded, weight: .semibold))
            Text(hint)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
