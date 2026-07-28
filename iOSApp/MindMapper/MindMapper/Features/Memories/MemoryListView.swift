import SwiftUI

/// Memories tab / pushed session memories — full UI in a later task.
struct MemoryListView: View {
    /// `nil` = all memories tab; non-nil = memories scoped to one chat.
    let sessionId: String?

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "lightbulb")
                .font(.theme.largeTitle)
                .foregroundStyle(Color.theme.textMuted)
            Text(sessionId == nil ? L10n.Memories.all : L10n.Memories.forChat)
                .headlineStyle()
            Text(L10n.Memories.placeholder)
                .secondaryStyle()
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.theme.background.ignoresSafeArea())
        .navigationTitle(sessionId == nil ? L10n.Memories.title : L10n.Memories.chatTitle)
    }
}
