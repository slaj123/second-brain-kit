# Newsletter Ingest (lightweight path)

Minimal-usage pipeline for TLDR-style daily newsletters (tagged `TLDR Newsletter`, or `TLDR` in the filename). Goal: keep a searchable, linked record of what was published while spending as few tokens as possible.

**Do NOT** run the full INGEST.md pipeline on these. Do NOT create per-edition source pages, new entity pages, new concept pages, syntheses, domain-hub updates, or confidence/tier bookkeeping. The weekly digest page IS the record.

---

## Per edition

For each newsletter file:

1. Read it. Boilerplate (sponsors, job ads, referral/footer) is already stripped.
2. Append the edition to the **weekly digest page** — the runner passes its exact path: `wiki/sources/<YYYY-Www>-newsletters.md`.
   - Create the page if missing, with frontmatter:
     ```yaml
     ---
     type: source
     created: <date>
     updated: <date>
     sources: 0
     domains: []   # whichever domains the week's stories touch
     tags: [newsletter, tldr]
     ---
     ```
   - Add one H2 per edition: `## <YYYY-MM-DD> — <edition title>`
   - Under it, one bullet per notable story: `- **<headline>** — one-line summary. [link](<url>)`
   - Group or drop trivial one-off items. Keep the article links — that is the point of the record.

---

## Major signals only

3. If a story is a genuinely major, recurring signal — frontier model release, funding/valuation over $1B, major geopolitical or regulatory move — **and an entity or concept page for it already exists**, add ONE cited line to that existing page. Never create a new page from a newsletter. When in doubt, leave it in the digest only.

---

## After all editions

4. In `index.md`, under a `## Newsletters` section (create it once if absent), keep ONE line per week:
   `- <YYYY-Www> — [[<YYYY-Www>-newsletters]] — <N> editions, <date range>`
   Do **not** add newsletters to the main Sources list.
5. Append ONE batch entry to `log.md`:
   ```
   ## [<date>] ingest | Newsletters (<N> editions)
   Domains: ai, technology. Pages touched: 1 digest. Tokens: <runner fills>. Notes: ...
   ```

Do not update domain hub overviews or their "Recent sources" sections. Work through all editions, then stop.
