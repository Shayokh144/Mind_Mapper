import SwiftUI

/// UI-ready session row — View never sees raw `Session` domain models.
struct SessionDisplayModel: Identifiable, Equatable {
    let id: String
    let title: String
    let topicTag: String?
    let relativeDate: String
    let iconName: String
    let iconColor: Color

    init(from session: Session) {
        id = session.id
        title = session.title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? L10n.Common.newConversation
        topicTag = session.topicTag.map { $0.rawValue.capitalized }
        relativeDate = session.updatedAt.formatted(.relative(presentation: .named))
        iconName = Self.iconName(for: session.topicTag)
        iconColor = Self.iconColor(for: session.topicTag)
    }

    static func iconName(for tag: Session.TopicTag?) -> String {
        switch tag {
        case .wardrobe: return "tshirt"
        case .plans: return "airplane"
        case .locations: return "mappin.and.ellipse"
        case .people: return "person.2"
        case .ideas: return "lightbulb"
        case .gifts: return "gift"
        case .work: return "briefcase"
        case .health: return "heart"
        case .other, .none: return "bubble.left"
        }
    }

    /// Topic tile tint — `Color.theme` tokens only (no raw hex).
    static func iconColor(for tag: Session.TopicTag?) -> Color {
        switch tag {
        case .wardrobe: return Color.theme.warning
        case .plans: return Color.theme.accent
        case .locations: return Color.theme.success
        case .people: return Color.theme.warning
        case .ideas: return Color.theme.accent
        case .gifts: return Color.theme.danger
        case .work: return Color.theme.textSecondary
        case .health: return Color.theme.danger
        case .other, .none: return Color.theme.textMuted
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
