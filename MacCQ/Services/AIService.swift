//
//  AIService.swift
//  MacCQ
//
//  Created by CreationWong on 2026/9/2.
//

import Foundation

struct ChatMessage: Codable {
    var role: String      // "system" / "user" / "assistant"
    var content: String
}

struct ChatRequest: Codable {
    var model: String
    var messages: [ChatMessage]
    var temperature: Double?
}

struct ChatResponse: Codable {
    var choices: [Choice]
    struct Choice: Codable {
        var message: ChatMessage
    }
}

/// AI 答疑（OpenAI 兼容接口），仅需配置端点与 Key
final class AIService {
    struct ChatError: Error, LocalizedError {
        var errorDescription: String?
        init(_ msg: String) { errorDescription = msg }
    }

    static let shared = AIService()

    func send(config: AIConfig, messages: [ChatMessage]) async throws -> String {
        guard config.isConfigured else {
            throw ChatError("请先在【设置】中配置 AI 端点、Key 与模型")
        }
        var base = config.baseURL
        while base.hasSuffix("/") { base.removeLast() }
        guard let url = URL(string: base + "/chat/completions") else {
            throw ChatError("无效的端点地址")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        let body = ChatRequest(model: config.model, messages: messages, temperature: 0.3)
        req.httpBody = try? JSONEncoder().encode(body)

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch {
            throw ChatError("网络请求失败：\(error.localizedDescription)")
        }
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "未知错误"
            throw ChatError("接口返回错误：\(msg)")
        }
        do {
            let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
            return decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } catch {
            throw ChatError("解析返回内容失败：\(error.localizedDescription)")
        }
    }
}
