# Build Session Close Pipeline (Auto Title, Summary & Embedding)

---

## Category
`ios`

## Estimated Time
⏱️ 4–5 hours

## Depends On
Task 11 (VectorStore), Task 14 (ChatViewModel for trigger point)

## Related Plan Section
📄 `../planning/execution-plan.md` → Phase 9 — Session Close Pipeline › Step 9.1 | Phase 7 Stage 3 (summary embeddings are used in future cross-session retrieval)

## Related UI
Session List — session rows get their title and topic tag icon from this pipeline. The coloured icon tiles (gift=pink, travel=blue etc.) seen in the Session List mockup depend on the topic tag generated here.

---

## What To Do

- [ ] **1.** Create `Domain/UseCases/CloseSessionUseCase.swift` with protocol and implementation.
- [ ] **2.** Implement `execute(sessionId: String) async throws` in the use case. Step 1: load all messages for the session from SQLite using `MessageRepository`. Guard that at least one message exists — if empty, return without doing anything. Step 2: build the full transcript as a string (role: content per line). Step 3: call `tier: .nano` to generate a 5-word title and one topic tag from the `TopicTag` enum. Parse the JSON response. Step 4: call `tier: .mini` to generate 3–5 bullet-point summary sentences. Step 5: save the title, topic tag, and summary to the session row in SQLite. Step 6: split the summary into individual bullets, embed each bullet separately using `LLMClient.shared.embed(text:tier: .embed)`, and save each as a new Memory row + Vector row tagged to this session.
- [ ] **3.** Use `async let` or `TaskGroup` for the two LLM calls in steps 3 and 4 — they can run in parallel as they both only need the transcript.
- [ ] **4.** Create `Data/Repositories/SessionRepository.swift` conforming to `SessionRepositoryProtocol`. Implement `update(_ session: Session)`, `fetchAll(for userId:)`, and `fetch(id:)`.
- [ ] **5.** Register `CloseSessionUseCase` and `SessionRepository` in `AppContainer`.
- [ ] **6.** In `ChatViewModel`, call `CloseSessionUseCase.execute()` in the `onDisappear` trigger. Also register an `AppLifecycleListener` in the chat view to trigger it when the app moves to background.
- [ ] **7.** Add a 2-minute inactivity timer in `ChatViewModel` — if no new message is sent for 120 seconds, trigger session close automatically.
- [ ] **8.** Verify the topic tag enum covers the mock data from the UI: 'gifts' for the gift session, 'plans' for Bali, 'wardrobe' for the T-shirt session, 'ideas' or 'plans' for the presentation outfit.

---

## ✅ Done When

- [ ] Have a multi-turn conversation, then leave the chat view → SQLite session row has a non-null title, topic_tag, and summary.
- [ ] The session list immediately shows the generated title after returning.
- [ ] Vector table has new rows for each summary bullet (typically 3–5 new rows).
- [ ] Days later, querying the summarised topic retrieves the summary bullets via Stage 1 vector search.
- [ ] App going to background triggers session close (test with Xcode debugger).

---

## 📝 Notes

The summary memory rows created in Step 6 are what enable cross-session retrieval. When a user asks 'What did we discuss about Bali?' days later, the Stage 1 vector search finds these summary bullets — not the original raw messages. This is why embedding them is essential, and why each bullet is embedded separately (for fine-grained retrieval precision).
