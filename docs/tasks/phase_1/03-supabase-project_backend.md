# Create Supabase Project & Install CLI

---

## Category
`backend`

## Estimated Time
⏱️ 1 hour

## Depends On
None — can be done in parallel with Tasks 1 and 2

## Related Plan Section
📄 `../planning/execution-plan.md` → Phase 0 — Environment Setup › Step 0.3 | About the Backend (Supabase) section

## Related UI
None — no UI built in this task

---

## What To Do

- [ ] **1.** Create a free account at supabase.com using your email address.
- [ ] **2.** Click New Project. Name it `MindMapper`. Choose region: Singapore (ap-southeast-1) — closest to Thailand for lowest latency.
- [ ] **3.** Set a strong database password and save it in your password manager.
- [ ] **4.** Wait for the project to finish provisioning (about 2 minutes).
- [ ] **5.** Go to Project Settings → API. Copy and save two values: Project URL (looks like `https://xxxx.supabase.co`) and the anon/public key.
- [ ] **6.** Install the Supabase CLI on your Mac using Homebrew: `brew install supabase/tap/supabase`
- [ ] **7.** Log in to the CLI: `supabase login` — this opens a browser window to authenticate.
- [ ] **8.** Link the CLI to your project: `supabase link --project-ref YOUR_PROJECT_REF` (the project ref is the part of your URL before `.supabase.co`).
- [ ] **9.** Verify the CLI connection: `supabase status` — it should show your project details.
- [ ] **10.** Store the Project URL and anon key safely — they will be added to the iOS app in Task 7 (Auth setup).

---

## ✅ Done When

- [ ] Supabase dashboard loads and shows your project.
- [ ] `supabase status` returns your project details without error.
- [ ] Project URL and anon key are copied and saved securely.

---

## 📝 Notes

Free Supabase projects pause after 7 days of inactivity. During active development this will not be a problem — just log in to the dashboard to resume if it pauses. The pause does not delete any data.
