//
//  AIConfig.swift
//  MacCQ
//
//  Created by CreationWong on 2026/9/2.
//

import Foundation

/// AI 答疑配置（OpenAI 兼容接口），用户只需填写端点与 Key
struct AIConfig: Codable, Equatable {
    var baseURL: String = ""
    var apiKey: String = ""
    var model: String = ""

    var isConfigured: Bool {
        !baseURL.isEmpty && !apiKey.isEmpty && !model.isEmpty
    }
}
