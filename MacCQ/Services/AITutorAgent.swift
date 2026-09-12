//
//  AITutorAgent.swift
//  MacCQ
//

import Foundation

/// AI 运行过程中的一步（思考或工具调用）
struct AgentStep: Identifiable {
    enum Kind { case thinking, tool }

    let id = UUID()
    let kind: Kind
    let title: String
    let detail: String
}

/// 一次 AI 助教运行的最终结果
struct AgentResult {
    let text: String
    let artifacts: [ChatArtifact]
    let steps: [AgentStep]
}

/// 基于工具的 AI 助教循环：
/// 模型可以反复调用工具（查询 / 出讲解 / 出测验 / 出考试），直到给出最终回答。
enum AITutorAgent {

    static func run(
        config: AIConfig,
        history: [ChatMessage],
        userMessage: String,
        systemPrompt: String,
        context: AIToolContext
    ) async throws -> AgentResult {
        var messages: [ChatMessage] = [ChatMessage(role: "system", content: systemPrompt)]
        messages.append(contentsOf: history)
        messages.append(ChatMessage(role: "user", content: userMessage))

        var artifacts: [ChatArtifact] = []
        var steps: [AgentStep] = []
        let maxIterations = 6

        for _ in 0..<maxIterations {
            let reply = try await AIService.shared.send(config: config, messages: messages)

            if let parsed = AITools.parseCall(from: reply) {
                if !parsed.thinking.isEmpty {
                    steps.append(AgentStep(kind: .thinking, title: "思考", detail: parsed.thinking))
                }

                let outcome = AITools.execute(parsed.call, context: context)
                steps.append(AgentStep(
                    kind: .tool,
                    title: AITools.describe(parsed.call),
                    detail: outcome.summary))
                if let artifact = outcome.artifact {
                    artifacts.append(artifact)
                }

                messages.append(ChatMessage(role: "assistant", content: "调用工具 \(parsed.call.name)"))
                messages.append(ChatMessage(role: "user", content: "【工具结果 \(parsed.call.name)】\n\(outcome.result)"))
                continue
            }

            // 带有工具字段但格式错误：提示模型重新输出
            if AITools.looksLikeToolCall(reply) {
                messages.append(ChatMessage(role: "assistant", content: reply))
                messages.append(ChatMessage(
                    role: "user",
                    content: "工具调用格式有误。请先简要说明思路，然后只输出一个合法的 JSON 对象，例如 {\"tool\":\"search_questions\",\"arguments\":{...}}。"))
                continue
            }

            return AgentResult(text: reply, artifacts: artifacts, steps: steps)
        }

        let final = try await AIService.shared.send(config: config, messages: messages + [
            ChatMessage(role: "user", content: "请用中文简要总结你为学员创建的训练内容，并告诉学员可以开始训练了。")
        ])
        return AgentResult(text: final, artifacts: artifacts, steps: steps)
    }
}
