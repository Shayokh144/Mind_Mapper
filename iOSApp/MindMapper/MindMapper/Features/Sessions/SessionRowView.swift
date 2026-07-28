import SwiftUI

/// Session list row: coloured icon tile + title / tag / relative date.
struct SessionRowView: View {
    let session: SessionDisplayModel

    private let iconSize: CGFloat = 38

    var body: some View {
        HStack(spacing: Spacing.md) {
            iconTile

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(session.title)
                    .headlineStyle()
                    .lineLimit(1)

                if let topicTag = session.topicTag {
                    Text(topicTag)
                        .captionStyle()
                        .lineLimit(1)
                }
            }

            Spacer(minLength: Spacing.sm)

            Text(session.relativeDate)
                .captionStyle()
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
        }
        .padding(.vertical, Spacing.xs)
        .contentShape(Rectangle())
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
    SessionRowView(
        session: SessionDisplayModel(
            from: Session(
                userId: "preview",
                title: "Anniversary gift ideas",
                topicTag: .gifts,
                updatedAt: Date().addingTimeInterval(-3_600)
            )
        )
    )
    .padding(Spacing.lg)
    .background(Color.theme.background)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    SessionRowView(
        session: SessionDisplayModel(
            from: Session(
                userId: "preview",
                title: "Bali trip plans",
                topicTag: .plans,
                updatedAt: Date().addingTimeInterval(-86_400)
            )
        )
    )
    .padding(Spacing.lg)
    .background(Color.theme.background)
    .preferredColorScheme(.dark)
}
