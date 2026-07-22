import SwiftUI

struct ThemeCard<Content: View>: View {
    @ViewBuilder let content: Content
    var padding: CGFloat = Spacing.lg

    var body: some View {
        content
            .padding(padding)
            .background(Color.theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
    }
}

#Preview("Light") {
    ThemeCard {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Gift ideas for wife").headlineStyle()
            Text("You decided on a watch and a scarf").secondaryStyle()
        }
    }
    .padding(Spacing.lg)
    .background(Color.theme.background)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    ThemeCard {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Gift ideas for wife").headlineStyle()
            Text("You decided on a watch and a scarf").secondaryStyle()
        }
    }
    .padding(Spacing.lg)
    .background(Color.theme.background)
    .preferredColorScheme(.dark)
}
