import SwiftUI

/// Session list row: coloured icon tile + title / capsule tag / relative date + pin + kebab.
struct ChatSessionRowView: View {
    let session: ChatSessionDisplayModel
    let onOpen: () -> Void
    let onMenuRename: () -> Void
    let onMenuUpdateTag: () -> Void

    private let iconSize: CGFloat = 38

    var body: some View {
        HStack(spacing: Spacing.md) {
            Button(action: onOpen) {
                HStack(spacing: Spacing.md) {
                    iconTile

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack(spacing: Spacing.xs) {
                            if session.isPinned {
                                Image(systemName: "pin.fill")
                                    .font(.theme.caption)
                                    .foregroundStyle(Color.theme.accent)
                                    .accessibilityLabel(L10n.Sessions.pinnedAccessibility)
                            }
                            Text(session.title)
                                .headlineStyle()
                                .lineLimit(1)
                        }

                        if let topicTag = session.topicTag {
                            ThemeBadge(
                                text: topicTag,
                                icon: session.iconName,
                                tint: session.iconColor
                            )
                        }
                    }

                    Spacer(minLength: Spacing.sm)

                    Text(session.relativeDate)
                        .captionStyle()
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                Button(L10n.Sessions.menuRename) {
                    onMenuRename()
                }
                Button(L10n.Sessions.menuUpdateTag) {
                    onMenuUpdateTag()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.theme.headline)
                    .foregroundStyle(Color.theme.textSecondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(L10n.Sessions.menuAccessibility)
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
    }

    private var iconTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .fill(session.iconColor.opacity(0.15))
                .frame(width: iconSize, height: iconSize)

            Image(systemName: session.iconName)
                .font(.theme.headline)
                .foregroundStyle(session.iconColor)
        }
        .accessibilityHidden(true)
    }
}

#Preview("Light") {
    ChatSessionRowView(
        session: ChatSessionDisplayModel(
            from: Session(
                userId: "preview",
                title: "Anniversary gift ideas",
                topicTag: .builtIn(.gifts),
                isPinned: true,
                updatedAt: Date().addingTimeInterval(-3_600)
            )
        ),
        onOpen: {},
        onMenuRename: {},
        onMenuUpdateTag: {}
    )
    .padding(Spacing.lg)
    .background(Color.theme.background)
    .preferredColorScheme(.light)
}

#Preview("Dark custom tag") {
    ChatSessionRowView(
        session: ChatSessionDisplayModel(
            from: Session(
                userId: "preview",
                title: "Holiday packing",
                topicTag: .custom("Holiday"),
                updatedAt: Date().addingTimeInterval(-86_400)
            )
        ),
        onOpen: {},
        onMenuRename: {},
        onMenuUpdateTag: {}
    )
    .padding(Spacing.lg)
    .background(Color.theme.background)
    .preferredColorScheme(.dark)
}
