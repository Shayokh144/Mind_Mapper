import SwiftUI

struct ChatView: View {
    /// Owned by this screen — SwiftUI keeps one instance for the view's lifetime.
    /// See https://developer.apple.com/documentation/swiftui/stateobject
    @StateObject private var viewModel: ChatViewModel
    @FocusState private var isInputFocused: Bool

    private let typingIndicatorId = "typing-indicator"

    init(viewModel: ChatViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            errorBanner
            editingFailedTurnBar
            sessionMessageQuotaBar
            inputBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.theme.background.ignoresSafeArea())
        .navigationTitle(
            viewModel.currentSession?.title ?? L10n.Chat.titleFallback
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        viewModel.openMemories()
                    } label: {
                        Label(L10n.Chat.viewMemories, systemImage: "lightbulb")
                    }
                    Button(role: .destructive) {
                        viewModel.requestDeleteConversation()
                    } label: {
                        Label(L10n.Chat.deleteConversation, systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(Color.theme.accent)
                }
                .accessibilityLabel(L10n.Chat.menuAccessibility)
            }
        }
        .confirmationDialog(
            L10n.Sessions.deleteTitle,
            isPresented: $viewModel.isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(L10n.Sessions.deleteConfirm, role: .destructive) {
                Task { await viewModel.confirmDeleteConversation() }
            }
            Button(L10n.Common.close, role: .cancel) {}
        } message: {
            Text(L10n.Sessions.deleteMessage)
        }
        .task {
            await viewModel.loadSession()
        }
        .onDisappear {
            Task {
                await viewModel.onLeaveChat()
            }
        }
        .onAppBackground {
            Task {
                await viewModel.closeSession()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .reminderEditorDidFinish)) { notification in
            let didSave = notification.userInfo?[ReminderEditorFinishUserInfoKey.didSave] as? Bool ?? false
            viewModel.handleReminderEditorFinished(didSave: didSave)
        }
        .confirmationDialog(
            L10n.Reminders.permissionPrePromptTitle,
            isPresented: $viewModel.showReminderPermissionPrePrompt,
            titleVisibility: .visible
        ) {
            Button(L10n.Reminders.permissionContinue) {
                Task { await viewModel.confirmReminderPermissionRequest() }
            }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Reminders.permissionPrePromptMessage)
        }
        .confirmationDialog(
            L10n.Reminders.deniedTitle,
            isPresented: $viewModel.showNotificationDeniedHelp,
            titleVisibility: .visible
        ) {
            Button(L10n.Settings.openSystemSettings) {
                openSystemSettings()
            }
            Button(L10n.Common.close, role: .cancel) {}
        } message: {
            Text(L10n.Reminders.deniedMessage)
        }
    }

    // MARK: - Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.md) {
                    if viewModel.messages.isEmpty && !viewModel.isLoading {
                        Text(L10n.Chat.empty)
                            .secondaryStyle()
                            .frame(maxWidth: .infinity)
                            .padding(.top, Spacing.xxl)
                    }

                    ForEach(viewModel.messages) { message in
                        messageRow(message)
                            .id(message.id)
                    }

                    if viewModel.isLoading {
                        TypingIndicator()
                            .id(typingIndicatorId)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) { _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.isLoading) { isLoading in
                if isLoading {
                    scrollToBottom(proxy: proxy, id: typingIndicatorId)
                } else {
                    scrollToBottom(proxy: proxy)
                }
            }
            .onChange(of: viewModel.canRetryLastTurn) { canRetry in
                if canRetry {
                    scrollToBottom(proxy: proxy)
                }
            }
        }
    }

    @ViewBuilder
    private func messageRow(_ message: MessageDisplayModel) -> some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: Spacing.sm) {
            ChatBubble(
                text: message.content,
                isUser: message.isUser,
                isWarning: message.isWarning
            )

            if shouldShowRetryActions(after: message) {
                retryActions
            }

            if shouldShowReminderOffer(after: message) {
                reminderOfferActions
            }

            if shouldShowCrossSessionBadge(after: message) {
                ThemeBadge(
                    text: L10n.Chat.foundAcross(count: viewModel.lastAnswerSessionCount),
                    icon: "sparkles",
                    role: .accent
                )
                .padding(.leading, Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
    }

    private func shouldShowReminderOffer(after message: MessageDisplayModel) -> Bool {
        guard viewModel.pendingReminderOffer != nil,
              message.isAssistant,
              message.id == viewModel.messages.last?.id
        else { return false }
        return true
    }

    private var reminderOfferActions: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(L10n.Reminders.offerPrompt)
                .captionStyle()
            HStack(spacing: Spacing.md) {
                GhostButton(title: L10n.Common.yes) {
                    Task { await viewModel.acceptReminderOffer() }
                }
                GhostButton(title: L10n.Common.no, color: Color.theme.textSecondary) {
                    viewModel.declineReminderOffer()
                }
            }
        }
        .padding(.leading, Spacing.xs)
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func shouldShowRetryActions(after message: MessageDisplayModel) -> Bool {
        viewModel.canRetryLastTurn && message.id == viewModel.lastFailedUserMessage?.id
    }

    private var retryActions: some View {
        HStack(spacing: Spacing.md) {
            GhostButton(title: L10n.Chat.retry) {
                Task { await viewModel.retryLastTurn() }
            }
            GhostButton(title: L10n.Chat.editAndRetry) {
                viewModel.beginEditFailedTurn()
                isInputFocused = true
            }
        }
        .padding(.trailing, Spacing.xs)
        .accessibilityElement(children: .contain)
    }

    private func shouldShowCrossSessionBadge(after message: MessageDisplayModel) -> Bool {
        guard viewModel.showsCrossSessionBadge,
              message.isAssistant,
              message.id == viewModel.messages.last?.id
        else { return false }
        return true
    }

    private func scrollToBottom(proxy: ScrollViewProxy, id: String? = nil) {
        let target = id
            ?? viewModel.messages.last?.id
            ?? (viewModel.isLoading ? typingIndicatorId : nil)
        guard let target else { return }
        withAnimation {
            proxy.scrollTo(target, anchor: .bottom)
        }
    }

    // MARK: - Error / retry / input

    @ViewBuilder
    private var errorBanner: some View {
        if let errorMessage = viewModel.errorMessage {
            ThemeBadge(text: errorMessage, icon: "exclamationmark.triangle", role: .warning)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onTapGesture { viewModel.errorMessage = nil }
        }
    }

    @ViewBuilder
    private var editingFailedTurnBar: some View {
        if viewModel.isEditingFailedTurn {
            HStack(spacing: Spacing.lg) {
                Text(L10n.Chat.editingFailedTurn)
                    .captionStyle()
                Spacer(minLength: 0)
                GhostButton(title: L10n.Common.close, color: Color.theme.textSecondary) {
                    viewModel.cancelEditFailedTurn()
                    isInputFocused = false
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.sm)
        }
    }

    private var sessionMessageQuotaBar: some View {
        SessionMessageQuotaBar(
            usedCount: viewModel.sessionMessageUsedCount,
            maxCount: ChatLimits.maxMessagesPerSession
        )
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.sm)
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: Spacing.sm) {
            ThemeTextField(
                text: $viewModel.inputText,
                placeholder: viewModel.isEditingFailedTurn
                    ? L10n.Chat.editFailedPlaceholder
                    : (viewModel.isSessionAtMessageLimit
                        ? L10n.Chat.sessionFullPlaceholder
                        : L10n.Chat.inputPlaceholder),
                maxLength: ChatLimits.maxCharactersPerMessage,
                isEnabled: !viewModel.isLoading && !viewModel.isSessionAtMessageLimit,
                focus: $isInputFocused
            )

            Text("\(viewModel.charactersRemaining)")
                .font(.theme.caption)
                .foregroundStyle(
                    viewModel.isCharacterCountWarning
                        ? Color.theme.danger
                        : Color.theme.textMuted
                )
                .frame(minWidth: 28, alignment: .trailing)
                .accessibilityLabel(L10n.Chat.charactersRemaining(viewModel.charactersRemaining))

            if viewModel.isLoading {
                Button {
                    viewModel.stopGenerating()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.theme.iconButton)
                        .foregroundStyle(Color.theme.onAccent)
                        .frame(width: 36, height: 36)
                        .background(Color.theme.accent)
                        .clipShape(Circle())
                }
                .accessibilityLabel(L10n.Chat.stopAccessibility)
            } else {
                Button {
                    isInputFocused = false
                    Task { await viewModel.sendMessage() }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.theme.iconButton)
                        .foregroundStyle(Color.theme.onAccent)
                        .frame(width: 36, height: 36)
                        .background(
                            viewModel.canSend ? Color.theme.accent : Color.theme.textMuted
                        )
                        .clipShape(Circle())
                }
                .disabled(!viewModel.canSend)
                .accessibilityLabel(
                    viewModel.isSessionAtMessageLimit
                        ? L10n.Chat.sessionFullSendAccessibility
                        : (viewModel.isEditingFailedTurn
                            ? L10n.Chat.saveAndRetryAccessibility
                            : L10n.Chat.sendAccessibility)
                )
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(Color.theme.background)
    }
}
