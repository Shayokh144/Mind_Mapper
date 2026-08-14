# Chat Send — Disable Input & Stop Generation

---

## Category
`ios`

## Estimated Time
⏱️ 1–2 hours

## Depends On
Task 14 (`ChatViewModel` pipeline), Task 18 (`ChatView` input bar + typing indicator)

## Related Plan Section
📄 `../planning/execution-plan.md` → Phase 11 — Step 11.2 Chat Screen

## Related UI
Chat input bar: text field disabled while a reply is in flight; send button swaps to a **stop** control (ChatGPT / Cursor / Gemini style). After stop, the last user turn stays incomplete so the user can edit and resend.

---

## What To Do

- [x] **1.** Track the in-flight send/retry as a cancellable `Task` on `ChatViewModel` (plus a generation token). Starting a new send cancels any prior task. Pipeline helpers (`runPipeline`, `appendAssistant`) must **ignore** results when the generation is stale or the task is cancelled — do not append an assistant bubble after stop.

- [x] **2.** Add `stopGenerating()` on `ChatViewModel`: cancel / invalidate the in-flight pipeline, clear `isLoading`, leave the last user message in place (incomplete turn). Prefills that message into the input via the edit-failed-turn path so the user can edit and send again immediately.

- [x] **3.** Keep `canSend` false while `isLoading`. Also **disable the text field** while loading (`ThemeTextField.isEnabled`).

- [x] **4.** Update `ChatView` input bar:
      - While `isLoading`: circular **stop** button (`stop.fill`); tapping calls `stopGenerating()`.
      - While not loading: existing send button (disabled when input empty).
      - Disable `ThemeTextField` when `isLoading`.

- [x] **5.** `L10n.Chat.stopAccessibility`. Execution-plan Step 11.2 note. Unit test: `test_stopGenerating_cancelsPipelineAndPrefillsEdit`.

---

## ✅ Done When

- [x] After send, until reply (or stop), the input field is not editable and a second message cannot be sent.
- [x] Send button becomes stop while waiting; stop cancels/ignores the in-flight request.
- [x] After stop, user can edit the previous user message and send again.
- [x] A late LLM response after stop does not appear in the chat.
- [x] Views stay thin; theme tokens only.

---

## 📝 Notes

**As shipped:**
- `pipelineTask` + `pipelineGeneration` invalidate on stop; cooperative cancel + ignore late results.
- Stop prefills the last user message into the input (`isEditingFailedTurn = true`).
- `ThemeTextField.isEnabled` for disabled styling while loading.

**Already shipped:** `isLoading` typing indicator, `canSend` includes `!isLoading`, incomplete-turn retry / edit UI.

**Out of scope:** Streaming token UI, aborting Edge Functions server-side.
