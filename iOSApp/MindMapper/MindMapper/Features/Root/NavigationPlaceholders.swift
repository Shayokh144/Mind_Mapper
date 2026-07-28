import SwiftUI

/// Sheet placeholder for `AppRouter.Sheet.newSession` until a dedicated composer exists.
struct NewSessionSheet: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.md) {
                Text(L10n.Common.newConversation)
                    .headlineStyle()
                Text(L10n.Sheet.newSessionBody)
                    .secondaryStyle()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.theme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) {
                        router.dismissSheet()
                    }
                }
            }
        }
    }
}

/// Sheet placeholder for `AppRouter.Sheet.memoryDetail`.
struct MemoryDetailPlaceholder: View {
    let memoryId: String
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.md) {
                Text(L10n.Memories.detailTitle)
                    .headlineStyle()
                Text(memoryId)
                    .captionStyle()
                Text(L10n.Memories.detailPlaceholder)
                    .secondaryStyle()
            }
            .padding(Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.theme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) {
                        router.dismissSheet()
                    }
                }
            }
        }
    }
}
