# Why Vector Blobs Are 6,144 Bytes

MindMapper stores each memory embedding in SQLite as a binary `BLOB`. Integration tests assert that blob is **exactly 6,144 bytes**. This doc explains what that number means and why it was chosen.

**Related code:** `Domain/Models/EmbeddingCodec.swift`, `Domain/Models/Vector.swift`, `Core/VectorStore/VectorStore.swift`, `vectors` table in `V1InitialMigration`  
**Related tasks:** [`06-database-layer_iOS.md`](../tasks/phase_1/06-database-layer_iOS.md), [`11-memory-save-pipeline_iOS.md`](../tasks/phase_1/11-memory-save-pipeline_iOS.md)  
**Related:** [`switching-llm-provider.md`](./switching-llm-provider.md)

---

## The short answer

```text
6,144 bytes = 1,536 floats × 4 bytes per Float32
```

Each memory gets one embedding vector of **1,536 dimensions**. Each dimension is a 32-bit float (`Float` in Swift). Packed into raw little-endian bytes (via `EmbeddingCodec`), that vector always occupies **6,144 bytes** on disk.

---

## What an embedding is (in this app)

When the user stores a fact, the save pipeline:

1. Extracts a clean standalone sentence (e.g. `"Blue T-shirt is in the 3rd drawer"`).
2. Calls `LLMClient.embed(text:tier: .embed)`.
3. Gets back `[Float]` — a point in high-dimensional space.
4. Serializes that array to `Data` and inserts a `vectors` row.

Later, a question is embedded the same way. **Cosine similarity** between the question vector and stored memory vectors finds “nearby” facts. Same length for every vector is required — you cannot compare a 768-d vector to a 1536-d one.

---

## Why we need an embedding model (e.g. `gemini-embedding-001`)

SQLite can store text and run `LIKE` / FTS keyword search. That is **not** enough for MindMapper’s “find the right memory” job.

### The problem keyword search cannot solve

User stores:

> “I put my blue T-shirt in the 3rd drawer”

User later asks:

> “Where is my navy tee?”

There is almost **no shared wording** (`T-shirt` ≠ `tee`, `blue` ≠ `navy`, no `drawer` in the question). A plain text match fails. Humans still know these mean the same thing. An **embedding model** encodes that kind of meaning into numbers so the two sentences land near each other in vector space.

Same idea for supersede lookup: hint `"perfume"` should find an older memory about a gift perfume even if the new message says “watch instead of the perfume.”

### What the model actually does

`LLMClient.embed` (tier `.embed` → today `gemini-embedding-001`, later OpenAI `text-embedding-3-small`) is a specialised **encoder**, not a chat reply:

| | Chat model (`.nano` / `.mini` / `.full`) | Embedding model (`.embed`) |
|--|------------------------------------------|----------------------------|
| Output | Words / JSON for the user or pipeline | Fixed-length `[Float]` (e.g. 1,536 numbers) |
| Job | Classify, extract, answer, acknowledge | Turn text into a comparable meaning vector |
| Used for | Intent, scope, extraction, synthesis | Save-time index + query-time retrieval |

You pass text in; you get a point in 1,536-d space out. Cosine similarity then ranks which stored points are closest to a new question. No embedding model → no semantic RAG; only brittle string matching.

### Why not roll our own vectors?

Home-grown hashes, bag-of-words, or TF–IDF:

- Do not reliably treat synonyms / paraphrase as similar.
- Break when the user rephrases weeks later.
- Would force us to maintain a vocabulary and tuning the app is not about.

Provider embedding models are trained on huge corpora so “passport in the safe” and “where did I put my travel documents?” can still score as related. MindMapper only stores the floats and compares them locally — the hard “understand language” work stays in `gemini-embedding-001` (dev) or OpenAI embeddings (prod).

### Why call it via the Edge Function?

Same reasons as chat completions ([`supabase-edge-functions-llm-proxy.md`](./supabase-edge-functions-llm-proxy.md)):

- API key never ships in the iOS binary.
- iOS always says `tier: .embed`; model IDs live in `LLMModelConfig` + the `embed` function.
- Swap Gemini → OpenAI later without rewriting `VectorStore` or save/query use cases.

### Mental model

```text
"Blue T-shirt is in the 3rd drawer"
        │
        ▼
  gemini-embedding-001  (or text-embedding-3-small)
        │
        ▼
  [Float × 1536]  →  BLOB 6144 bytes  →  SQLite vectors
        │
        ▼  (days later)
"Where is my navy tee?" → embed again → cosine vs stored blobs → hit
```

**Bottom line for this section:** We need an embedding LLM because retrieval is **meaning-based**, not keyword-based. Chat models write answers; embedding models produce the numbers that make “find my memory” work.

---

## Why 1,536 dimensions?

The project standardized on **1,536** because that is the native size of the intended **production** embedding models:

| When | Model | Dimensions |
|------|--------|------------|
| Production (planned) | OpenAI `text-embedding-3-small` | 1,536 |
| Production fallback | OpenAI `text-embedding-ada-002` | 1,536 |
| Dev today | Gemini `gemini-embedding-001` | provider-dependent (see caveat) |

1,536 is a widely used “small embedding” size: enough semantic resolution for personal-memory retrieval, still cheap to store (~6 KB per memory). Larger models (e.g. 3,072-d) improve quality a bit but roughly double blob size and similarity cost.

The schema and tests lock that contract early so vector search, supersede lookup, and future pgvector sync all assume one fixed width.

---

## Why a BLOB (not JSON / text)?

Storing `[0.12, -0.45, …]` as JSON would:

- Use far more space (digits + commas + brackets).
- Be slower to encode/decode on every search.
- Tempt accidental precision loss when parsing numbers.

A raw float buffer is:

- Fixed size → easy integrity check (`data.count == 6144`).
- Fast to round-trip with `EmbeddingCodec.encode` / `.decode`.
- Natural for GRDB `blob` columns and later for `vector(1536)` on Postgres.

```swift
// Domain/Models/EmbeddingCodec.swift
EmbeddingCodec.encode([Float]) // → Data (6144 bytes when count == 1536)
EmbeddingCodec.decode(Data)    // → [Float]
```

---

## Why tests assert `6144`

Task 11’s Done When item is not arbitrary QA trivia. Asserting blob length catches:

| Failure mode | What goes wrong |
|--------------|-----------------|
| Wrong float count from mock / provider | Cosine similarity silently wrong or crashes on zip |
| Accidentally encoding `Double` (8 bytes) | 12,288-byte blobs; breaks the contract |
| Truncated / empty embed response | Zero-length or short blob stored as if valid |
| Codec endianness / buffer bugs | Round-trip tests + size check fail early |

In unit/integration tests, `MockLLMService` returns a synthetic `[Float]` of length **1,536**, so a successful save always writes a **6,144-byte** blob without calling the real API.

---

## Caveat: Gemini vs OpenAI dimensions

Dev currently uses `gemini-embedding-001`. Google’s embedding APIs can return **different widths** depending on model and `outputDimensionality` settings (not always 1,536).

MindMapper’s **on-device contract** is still “1536 floats → 6144-byte blob,” because:

1. Production target is OpenAI 1536-d models (`docs/pre-release-checklist.md`).
2. Local SQLite and future `pgvector(1536)` need one fixed size.
3. Cosine search assumes equal-length vectors.

If a live Gemini response is not 1,536 floats, treat that as a **provider/config bug** to fix in the Edge Function (request/truncate/pad to 1536, or reject), not as a reason to relax the SQLite blob size. When switching providers, keep the embed Edge Function returning a 1536-length array so iOS and tests stay unchanged — see [`switching-llm-provider.md`](./switching-llm-provider.md).

---

## Storage cost (order of magnitude)

| Memories | Vector storage (approx.) |
|----------|---------------------------|
| 1 | 6 KB |
| 1,000 | ~6 MB |
| 10,000 | ~60 MB |

Plus text rows, entities, and indexes — still fine for on-device personal use at Phase 1 scale.

---

## Bottom line

We need an embedding model (`gemini-embedding-001` today) so memories can be found by **meaning**, not exact words. **6,144 bytes** means “one memory embedding of **1,536 × Float32**,” chosen to match the production OpenAI embedding width, keep cosine search consistent, and give tests a hard integrity check. The number is a **format contract**, not a magic SQLite limit.
