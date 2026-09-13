//
//  ChatHistory.swift
//  MacCQ
//

import Foundation

/// 一次对话会话
struct ChatSession: Identifiable, Hashable {
    var id: Int64
    var title: String
    var createdAt: Date
    var updatedAt: Date
}

/// 对话消息的持久化结构
struct ChatMessageRecord {
    var id: Int64 = 0
    var role: String
    var content: String
    var apiContent: String?
    var steps: [AgentStep] = []
    var artifacts: [StoredArtifact] = []
    var createdAt: Date = Date()
    var sessionId: Int64 = 0
}

/// 可持久化的训练产物（讲解 / 测验 / 考试）
struct StoredArtifact: Codable {
    enum Kind: String, Codable {
        case lesson, quiz, exam
    }

    var kind: Kind
    var title: String
    var topic: String?
    var level: String
    var minutes: Int?
    var slides: [LessonSlide]?
    var questions: [ExamQuestion]?

    init(_ artifact: ChatArtifact) {
        switch artifact {
        case .lesson(let a):
            kind = .lesson
            title = a.title
            topic = a.topic
            level = a.level.rawValue
            minutes = nil
            slides = a.slides
            questions = nil
        case .quiz(let a):
            kind = .quiz
            title = a.title
            topic = nil
            level = a.level.rawValue
            minutes = nil
            slides = nil
            questions = a.questions
        case .exam(let a):
            kind = .exam
            title = a.title
            topic = nil
            level = a.level.rawValue
            minutes = a.minutes
            slides = nil
            questions = a.questions
        }
    }

    var artifact: ChatArtifact? {
        let resolvedLevel = Level(rawValue: level) ?? .a
        switch kind {
        case .lesson:
            guard let slides else { return nil }
            return .lesson(LessonArtifact(
                title: title, topic: topic ?? "", level: resolvedLevel, slides: slides))
        case .quiz:
            guard let questions else { return nil }
            return .quiz(QuizArtifact(title: title, level: resolvedLevel, questions: questions))
        case .exam:
            guard let questions else { return nil }
            return .exam(ExamArtifact(
                title: title, level: resolvedLevel,
                minutes: minutes ?? resolvedLevel.timeMinutes, questions: questions))
        }
    }
}
