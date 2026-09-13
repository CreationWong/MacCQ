//
//  AITools.swift
//  MacCQ
//

import Foundation

// MARK: - 训练产物

struct LessonArtifact: Identifiable {
    let id = UUID()
    let title: String
    let topic: String
    let level: Level
    let slides: [LessonSlide]
}

struct QuizArtifact: Identifiable {
    let id = UUID()
    let title: String
    let level: Level
    let questions: [ExamQuestion]
}

struct ExamArtifact: Identifiable {
    let id = UUID()
    let title: String
    let level: Level
    let minutes: Int
    let questions: [ExamQuestion]
}

/// AI 通过工具创建的产物
enum ChatArtifact: Identifiable {
    case lesson(LessonArtifact)
    case quiz(QuizArtifact)
    case exam(ExamArtifact)

    var id: UUID {
        switch self {
        case .lesson(let a): return a.id
        case .quiz(let a): return a.id
        case .exam(let a): return a.id
        }
    }

    var title: String {
        switch self {
        case .lesson(let a): return a.title
        case .quiz(let a): return a.title
        case .exam(let a): return a.title
        }
    }

    var kindTitle: String {
        switch self {
        case .lesson: return "讲解"
        case .quiz: return "测验"
        case .exam: return "考试"
        }
    }

    var icon: String {
        switch self {
        case .lesson: return "rectangle.on.rectangle"
        case .quiz: return "checklist"
        case .exam: return "doc.text"
        }
    }

    var level: Level {
        switch self {
        case .lesson(let a): return a.level
        case .quiz(let a): return a.level
        case .exam(let a): return a.level
        }
    }
}

// MARK: - 工具上下文

/// AI 可读取的学员数据快照
struct AIToolContext {
    let bank: [Question]
    let wrongQuestions: [Question]
    let favoriteQuestions: [Question]
    let records: [ExamRecord]
    let defaultLevel: Level
}

// MARK: - 工具调用

struct AIToolCall {
    let name: String
    let arguments: [String: Any]
}

struct AIToolOutcome {
    /// 返回给 AI 的完整结果
    let result: String
    /// 展示给学员的简短摘要
    let summary: String
    /// 要展示给学员的产物
    let artifact: ChatArtifact?
}

/// AI 可调用的工具：查询题目、查询知识、出讲解、出测验、出考试。
enum AITools {

    // MARK: - 系统提示词

    /// 角色 + 学员情况 + 工具协议
    static func systemPrompt(profile: String) -> String {
        """
        你是一名中国业余无线电操作证考试的辅导老师，熟悉《业余无线电台管理办法》和相关法规、通信操作与无线电技术知识。
        请用简体中文、条理清晰地与学员交流。

        【学员情况】
        \(profile.isEmpty ? "（暂无记录）" : profile)

        【可用工具】
        你可以调用工具来查询学员数据或知识、创建讲解（PPT）、测验和考试。
        调用工具时，先简要说明你的思路（一两句话），然后在最后输出一个 JSON 对象。
        必须使用 {"tool":"工具名","arguments":{...}} 的完整格式，不要省略外层的 tool 与 arguments，
        也不要用 Markdown 代码块包裹 JSON。JSON 之后不要再输出任何内容。
        内容要精简：每条要点不超过 40 字，避免输出过长导致中断。

        工具列表：
        1. search_questions — 查询题库、错题本、收藏或考试记录
           arguments: {"source":"bank|wrong|favorite|records","query":"关键词，可选","level":"A|B|C，可选","limit":5}
        2. search_knowledge — 查询内置的业余无线电知识库
           arguments: {"query":"关键词","limit":3}
        3. create_lesson — 创建讲解幻灯片（PPT）
           arguments: {"title":"标题","topic":"主题","level":"A","slides":[{"title":"小标题","points":["要点1","要点2"],"example":"例子，可选"}]}
           要求 4~6 页，内容准确、口语化，便于学员理解。
        4. create_quiz — 创建测验（带解析的练习题）
           arguments: {"title":"标题","level":"A","questions":[{"type":"single|multi","stem":"题干","options":["选项1","选项2","选项3","选项4"],"answer":"A","explanation":"解析"}]}
           要求 5 题左右，覆盖学员薄弱点。
        5. create_exam — 创建限时考试（从题库中选取真题组卷）
           arguments: {"title":"标题","level":"A","topics":["主题1","主题2"],"question_count":20,"minutes":40}
           真题由系统从题库按主题挑选，你不需要给出题目。

        【工作方式】
        1. 先判断是否需要工具：只有在确实需要了解学员数据（题库、错题本、收藏、考试记录）或知识细节时，才调用 search_questions / search_knowledge。
        2. 日常问候、闲聊、或你有把握直接回答的问题，直接回答，不要调用任何工具，也不要臆测学员的题目。
        3. 当学员想练习、巩固某个主题，或你判断需要针对薄弱点训练时，再调用 create_lesson / create_quiz / create_exam（可只创建其中一部分）。
        4. 工具完成后用中文简要说明你做了什么，并告诉学员可以开始训练。
        一次只调用一个工具。
        """
    }

    // MARK: - 解析工具调用

    /// 从模型回复中解析工具调用；返回（思考文本，工具调用）。
    /// 兼容两种输出：
    /// 1. 规范格式 {"tool":"...","arguments":{...}}
    /// 2. 模型直接给出的参数对象（根据字段推断工具）
    static func parseCall(from text: String) -> (thinking: String, call: AIToolCall)? {
        for object in jsonObjects(in: text) {
            guard let data = object.json.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

            let call: AIToolCall
            if let tool = (dict["tool"] as? String) ?? (dict["name"] as? String) {
                var arguments = (dict["arguments"] as? [String: Any]) ?? [:]
                // 兼容 arguments 被序列化成字符串的情况
                if arguments.isEmpty, let text = dict["arguments"] as? String,
                   let data = text.data(using: .utf8),
                   let parsedArguments = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    arguments = parsedArguments
                }
                if arguments.isEmpty {
                    arguments = dict.filter { $0.key != "tool" && $0.key != "name" && $0.key != "arguments" }
                }
                call = AIToolCall(name: tool, arguments: arguments)
            } else if dict["slides"] != nil {
                call = AIToolCall(name: "create_lesson", arguments: dict)
            } else if dict["questions"] != nil {
                call = AIToolCall(name: "create_quiz", arguments: dict)
            } else if dict["topics"] != nil || dict["question_count"] != nil || dict["questionCount"] != nil {
                call = AIToolCall(name: "create_exam", arguments: dict)
            } else if dict["source"] != nil || dict["query"] != nil {
                call = AIToolCall(name: "search_questions", arguments: dict)
            } else {
                continue
            }

            var thinking = text
            thinking.removeSubrange(object.range)
            thinking = thinking
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return (thinking, call)
        }
        return nil
    }

    /// 回复里是否出现了疑似工具调用的内容（含被截断、未按规范包裹的情况）
    static func looksLikeToolCall(_ text: String) -> Bool {
        if text.contains("\"tool\"") || text.contains("\"arguments\"") { return true }
        return containsToolPayload(in: text)
    }

    /// 清理展示文本：移除包含工具参数 JSON 的代码块，避免把原始 JSON 显示给学员
    static func cleanDisplayText(_ text: String) -> String {
        let pattern = #"```[a-zA-Z]*\s*[\s\S]*?```"#
        var result = text
        if let re = try? NSRegularExpression(pattern: pattern) {
            let matches = re.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches.reversed() {
                guard let range = Range(match.range, in: result) else { continue }
                let block = String(result[range])
                if containsToolPayload(in: block) {
                    result.removeSubrange(range)
                }
            }
        }
        // 输出被截断、代码块没有闭合的情况：从最后一个 ``` 起全部移除
        if let fence = result.range(of: "```", options: .backwards),
           containsToolPayload(in: String(result[fence.lowerBound...])) {
            result.removeSubrange(fence.lowerBound...)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func containsToolPayload(in text: String) -> Bool {
        ["\"slides\"", "\"questions\"", "\"topics\"", "\"question_count\"", "\"tool\"", "\"arguments\""]
            .contains { text.contains($0) }
    }

    /// 工具调用的简短描述（用于展示）
    static func describe(_ call: AIToolCall) -> String {
        switch call.name {
        case "search_questions":
            let source = call.arguments["source"] as? String ?? "bank"
            let sourceName = ["bank": "题库", "wrong": "错题本", "favorite": "收藏", "records": "考试记录"][source] ?? source
            let query = call.arguments["query"] as? String ?? ""
            return query.isEmpty ? "查询\(sourceName)" : "查询\(sourceName)：\(query)"
        case "search_knowledge":
            return "查询知识：\((call.arguments["query"] as? String) ?? "")"
        case "create_lesson":
            return "生成讲解：\((call.arguments["topic"] as? String) ?? (call.arguments["title"] as? String ?? ""))"
        case "create_quiz":
            return "生成测验：\((call.arguments["title"] as? String) ?? "专项测验")"
        case "create_exam":
            let topics = (call.arguments["topics"] as? [String])?.joined(separator: "、") ?? ""
            return "生成考试：\(topics.isEmpty ? "综合" : topics)"
        default:
            return call.name
        }
    }

    // MARK: - 执行工具

    static func execute(_ call: AIToolCall, context: AIToolContext) -> AIToolOutcome {
        switch call.name {
        case "search_questions":
            return searchQuestions(call.arguments, context: context)
        case "search_knowledge":
            return searchKnowledge(call.arguments)
        case "create_lesson":
            return createLesson(call.arguments, context: context)
        case "create_quiz":
            return createQuiz(call.arguments, context: context)
        case "create_exam":
            return createExam(call.arguments, context: context)
        default:
            return AIToolOutcome(result: "错误：未知工具 \(call.name)", summary: "未知工具 \(call.name)", artifact: nil)
        }
    }

    // MARK: - search_questions

    private static func searchQuestions(_ arguments: [String: Any], context: AIToolContext) -> AIToolOutcome {
        let source = (arguments["source"] as? String) ?? "bank"
        let query = (arguments["query"] as? String) ?? ""
        let level = (arguments["level"] as? String)
            .map { $0.uppercased() }
            .flatMap { Level(rawValue: $0) }
        let limit = min(max((arguments["limit"] as? Int) ?? 5, 1), 20)

        switch source {
        case "wrong":
            let items = filter(context.wrongQuestions, query: query, level: level, limit: limit)
            return AIToolOutcome(
                result: encodeQuestions(items, title: "错题本", total: context.wrongQuestions.count),
                summary: "错题本共 \(context.wrongQuestions.count) 题，匹配 \(items.count) 条",
                artifact: nil)

        case "favorite":
            let items = filter(context.favoriteQuestions, query: query, level: level, limit: limit)
            return AIToolOutcome(
                result: encodeQuestions(items, title: "收藏", total: context.favoriteQuestions.count),
                summary: "收藏共 \(context.favoriteQuestions.count) 题，匹配 \(items.count) 条",
                artifact: nil)

        case "records":
            let items = context.records.prefix(limit).map { record -> [String: Any] in
                var item: [String: Any] = [
                    "date": record.date.formatted(.dateTime.year().month().day()),
                    "level": record.level,
                    "score": "\(record.correct)/\(record.total)",
                    "passed": record.passed,
                ]
                if !record.weakTopics.isEmpty {
                    item["weak_topics"] = record.weakTopics
                }
                return item
            }
            return AIToolOutcome(
                result: encode(["考试记录": Array(items)]),
                summary: "查询到 \(items.count) 条考试记录",
                artifact: nil)

        default:
            var pool = context.bank
            if let level {
                pool = pool.filter { $0.level == level.rawValue }
            }
            let items: [Question]
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                items = Array(pool.prefix(limit))
            } else {
                items = QuestionMatcher.related(to: query, bank: pool, limit: limit)
            }
            let title = query.isEmpty ? "题库" : "题库（\(query)）"
            return AIToolOutcome(
                result: encodeQuestions(items, title: title, total: pool.count),
                summary: "\(title)共 \(pool.count) 题，匹配 \(items.count) 条",
                artifact: nil)
        }
    }

    private static func filter(_ questions: [Question], query: String, level: Level?, limit: Int) -> [Question] {
        var result = questions
        if let level {
            result = result.filter { $0.level == level.rawValue }
        }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            result = result.filter {
                $0.stem.localizedCaseInsensitiveContains(trimmed)
                    || $0.options.contains { $0.localizedCaseInsensitiveContains(trimmed) }
            }
        }
        return Array(result.prefix(limit))
    }

    private static func encodeQuestions(_ questions: [Question], title: String, total: Int) -> String {
        let items = questions.map { q -> [String: Any] in
            let answer = q.correct.sorted().map { ExamEngine.optionLetter($0) }.joined()
            return [
                "id": q.id,
                "level": q.level,
                "type": q.type.label,
                "stem": q.stem,
                "options": q.options,
                "answer": answer,
            ]
        }
        return encode([
            "来源": title,
            "匹配数量": items.count,
            "总量": total,
            "题目": items,
        ])
    }

    // MARK: - search_knowledge

    private static func searchKnowledge(_ arguments: [String: Any]) -> AIToolOutcome {
        let query = (arguments["query"] as? String) ?? ""
        let limit = min(max((arguments["limit"] as? Int) ?? 3, 1), 6)
        let entries = KnowledgeBase.search(query, limit: limit)
        guard !entries.isEmpty else {
            return AIToolOutcome(result: "没有找到相关的知识要点。", summary: "知识库未命中", artifact: nil)
        }
        let items = entries.map { ["title": $0.title, "category": $0.category, "content": $0.content] }
        return AIToolOutcome(
            result: encode(["知识": items]),
            summary: "命中 \(entries.count) 条知识：\(entries.map(\.title).joined(separator: "、"))",
            artifact: nil)
    }

    // MARK: - create_lesson

    private struct LessonArgs: Decodable {
        let title: String?
        let topic: String?
        let level: String?
        let slides: [LessonSlide]
    }

    private static func createLesson(_ arguments: [String: Any], context: AIToolContext) -> AIToolOutcome {
        guard let args = decode(LessonArgs.self, from: arguments) else {
            return AIToolOutcome(result: "错误：create_lesson 参数不完整", summary: "参数不完整", artifact: nil)
        }
        let slides = args.slides.filter { !$0.title.isEmpty || !$0.points.isEmpty }
        guard !slides.isEmpty else {
            return AIToolOutcome(result: "错误：slides 不能为空", summary: "slides 为空", artifact: nil)
        }
        let level = args.level.flatMap { Level(rawValue: $0.uppercased()) } ?? context.defaultLevel
        let topic = args.topic ?? ""
        let title = args.title ?? "\(topic.isEmpty ? "专项" : topic)讲解"
        let artifact = ChatArtifact.lesson(LessonArtifact(
            title: title, topic: topic, level: level, slides: slides))
        return AIToolOutcome(
            result: "已创建讲解《\(title)》，共 \(slides.count) 页。",
            summary: "共 \(slides.count) 页",
            artifact: artifact)
    }

    // MARK: - create_quiz

    private struct QuizArgs: Decodable {
        let title: String?
        let level: String?
        let questions: [GeneratedQuestion]
    }

    private static func createQuiz(_ arguments: [String: Any], context: AIToolContext) -> AIToolOutcome {
        guard let args = decode(QuizArgs.self, from: arguments) else {
            return AIToolOutcome(result: "错误：create_quiz 参数不完整", summary: "参数不完整", artifact: nil)
        }
        let level = args.level.flatMap { Level(rawValue: $0.uppercased()) } ?? context.defaultLevel
        let questions = AIQuestionGenerator.examQuestions(from: args.questions, level: level)
        guard !questions.isEmpty else {
            return AIToolOutcome(result: "错误：没有可用的题目", summary: "没有可用题目", artifact: nil)
        }
        let title = args.title ?? "专项测验"
        let artifact = ChatArtifact.quiz(QuizArtifact(title: title, level: level, questions: questions))
        return AIToolOutcome(
            result: "已创建测验《\(title)》，共 \(questions.count) 题（含解析）。",
            summary: "共 \(questions.count) 题（含解析）",
            artifact: artifact)
    }

    // MARK: - create_exam

    private struct ExamArgs: Decodable {
        let title: String?
        let level: String?
        let topics: [String]?
        let questionCount: Int?
        let minutes: Int?

        enum CodingKeys: String, CodingKey {
            case title, level, topics, minutes
            case questionCount = "question_count"
        }
    }

    private static func createExam(_ arguments: [String: Any], context: AIToolContext) -> AIToolOutcome {
        guard let args = decode(ExamArgs.self, from: arguments) else {
            return AIToolOutcome(result: "错误：create_exam 参数不完整", summary: "参数不完整", artifact: nil)
        }
        let level = args.level.flatMap { Level(rawValue: $0.uppercased()) } ?? context.defaultLevel
        let count = min(max(args.questionCount ?? 20, 5), 60)
        let minutes = min(max(args.minutes ?? level.timeMinutes, 5), 180)
        let topics = args.topics ?? []

        let wrongIds = Set(context.wrongQuestions.map(\.id))
        let favoriteIds = Set(context.favoriteQuestions.map(\.id))

        var chosen: [Question] = []
        var seen = Set<Int64>()
        for topic in topics where chosen.count < count {
            let matches = AITrainingService.selectRealQuestions(
                topic: topic, level: level, bank: context.bank,
                wrongIds: wrongIds, favoriteIds: favoriteIds, limit: count)
            for q in matches where seen.insert(q.id).inserted {
                chosen.append(q)
            }
        }
        // 不足时从题库补充
        if chosen.count < count {
            let pool = context.bank.filter { $0.level == level.rawValue && !seen.contains($0.id) }
            for q in pool.shuffled() where chosen.count < count && seen.insert(q.id).inserted {
                chosen.append(q)
            }
        }

        guard !chosen.isEmpty else {
            return AIToolOutcome(
                result: "错误：题库中没有可用于组卷的题目，请学员先导入题库。",
                summary: "题库为空，无法组卷",
                artifact: nil)
        }

        let exam = ExamEngine.buildExam(bank: chosen, count: min(count, chosen.count))
        let title = args.title ?? "\(level.shortName)模拟考试"
        let artifact = ChatArtifact.exam(ExamArtifact(
            title: title, level: level, minutes: minutes, questions: exam))
        let topicText = topics.isEmpty ? "综合" : topics.joined(separator: "、")
        return AIToolOutcome(
            result: "已创建考试《\(title)》：\(exam.count) 题，限时 \(minutes) 分钟，覆盖 \(topicText)。",
            summary: "\(exam.count) 题，限时 \(minutes) 分钟",
            artifact: artifact)
    }

    // MARK: - 工具

    private static func decode<T: Decodable>(_ type: T.Type, from arguments: [String: Any]) -> T? {
        guard let data = try? JSONSerialization.data(withJSONObject: arguments) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func encode(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.withoutEscapingSlashes]),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    /// 提取文本中所有顶层 JSON 对象及其范围（支持字符串与转义）
    private static func jsonObjects(in text: String) -> [(json: String, range: Range<String.Index>)] {
        let chars = Array(text)
        var results: [(String, Range<String.Index>)] = []
        var depth = 0
        var start: Int?
        var inString = false
        var escaped = false

        for (i, c) in chars.enumerated() {
            if inString {
                if escaped {
                    escaped = false
                } else if c == "\\" {
                    escaped = true
                } else if c == "\"" {
                    inString = false
                }
                continue
            }
            if c == "\"" {
                inString = true
            } else if c == "{" {
                if depth == 0 { start = i }
                depth += 1
            } else if c == "}" {
                depth -= 1
                if depth == 0, let s = start {
                    let lower = text.index(text.startIndex, offsetBy: s)
                    let upper = text.index(text.startIndex, offsetBy: i + 1)
                    results.append((String(chars[s...i]), lower..<upper))
                    start = nil
                }
                if depth < 0 { depth = 0 }
            }
        }
        return results
    }
}
