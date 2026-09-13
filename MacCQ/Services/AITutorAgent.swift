//
//  AITutorAgent.swift
//  MacCQ
//

import Foundation

/// AI 运行过程中的一步（思考或工具调用）
struct AgentStep: Identifiable, Codable {
    enum Kind: String, Codable { case thinking, tool }

    let id: UUID
    let kind: Kind
    let title: String
    let detail: String

    init(kind: Kind, title: String, detail: String) {
        self.id = UUID()
        self.kind = kind
        self.title = title
        self.detail = detail
    }
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

                // 回放模型真实的工具调用内容，避免用假消息导致模型模仿而中断
                messages.append(ChatMessage(role: "assistant", content: reply))
                messages.append(ChatMessage(role: "user", content: "【工具结果 \(parsed.call.name)】\n\(outcome.result)"))
                continue
            }

            // 模型把内部提示当成了回答（例如只输出「调用工具 …」），提示它继续
            let trimmedReply = reply.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedReply.contains("调用工具"), trimmedReply.count < 60 {
                messages.append(ChatMessage(role: "assistant", content: reply))
                messages.append(ChatMessage(
                    role: "user",
                    content: "请继续完成任务：如果需要调用工具，请输出完整的 {\"tool\":\"工具名\",\"arguments\":{...}}；否则请直接用中文回答。"))
                continue
            }

            // 带有工具字段但格式错误（或输出被截断）：提示模型重新输出，绝不把原始 JSON 展示给学员
            if AITools.looksLikeToolCall(reply) {
                messages.append(ChatMessage(role: "assistant", content: "（工具调用未完成）"))
                messages.append(ChatMessage(
                    role: "user",
                    content: "工具调用格式有误或内容被截断。请只输出一个合法的 JSON 对象：{\"tool\":\"工具名\",\"arguments\":{...}}，不要用 Markdown 代码块包裹，也不要输出其他内容。内容请精简一些。"))
                continue
            }

            return AgentResult(
                text: AITools.cleanDisplayText(reply),
                artifacts: artifacts,
                steps: steps)
        }

        let final = try await AIService.shared.send(config: config, messages: messages + [
            ChatMessage(role: "user", content: "请用中文简要总结你为学员创建的训练内容，并告诉学员可以开始训练了。")
        ])
        return AgentResult(
            text: AITools.cleanDisplayText(final),
            artifacts: artifacts,
            steps: steps)
    }
}
