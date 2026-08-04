import SwiftUI

/// UI-ready session row — View never sees raw `Session` domain models.
struct ChatSessionDisplayModel: Identifiable, Equatable {
    let id: String
    let title: String
    /// Raw title for the edit sheet (empty when using the display fallback).
    let editableTitle: String
    let topicTag: String?
    let relativeDate: String
    let iconName: String
    let iconColor: Color
    let isPinned: Bool
    let isCustomTopicTag: Bool

    init(from session: Session) {
        id = session.id
        let trimmedTitle = session.title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        title = trimmedTitle ?? L10n.Common.newConversation
        editableTitle = trimmedTitle ?? ""
        topicTag = session.topicTag?.displayLabel
        relativeDate = session.updatedAt.formatted(.relative(presentation: .named))
        iconName = Self.iconName(for: session.topicTag)
        iconColor = Self.iconColor(for: session.topicTag)
        isPinned = session.isPinned
        isCustomTopicTag = session.topicTag?.isCustom == true
    }

    static func iconName(for topic: Session.Topic?) -> String {
        guard let topic else { return "bubble.left" }
        switch topic {
        case let .builtIn(tag):
            return iconName(for: tag)
        case .custom:
            return "tag"
        }
    }

    static func iconName(for tag: Session.TopicTag) -> String {
        switch tag {
        case .wardrobe: return "tshirt"
        case .plans: return "airplane"
        case .locations: return "mappin.and.ellipse"
        case .people: return "person.2"
        case .ideas: return "lightbulb"
        case .gifts: return "gift"
        case .work: return "briefcase"
        case .health: return "heart"
        case .other: return "bubble.left"
        }
    }

    /// Topic tile / capsule tint — `Color.theme` tokens only (no raw hex).
    /// Custom tags use `splashBackground` so they read distinct from built-ins.
    static func iconColor(for topic: Session.Topic?) -> Color {
        guard let topic else { return Color.theme.textMuted }
        switch topic {
        case let .builtIn(tag):
            return iconColor(for: tag)
        case .custom:
            return Color.theme.splashBackground
        }
    }

    static func iconColor(for tag: Session.TopicTag) -> Color {
        switch tag {
        case .wardrobe: return Color.theme.warning
        case .plans: return Color.theme.accent
        case .locations: return Color.theme.success
        case .people: return Color.theme.warning
        case .ideas: return Color.theme.accent
        case .gifts: return Color.theme.danger
        case .work: return Color.theme.textSecondary
        case .health: return Color.theme.danger
        case .other: return Color.theme.textMuted
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
