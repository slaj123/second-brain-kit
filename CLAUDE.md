# Personal Second Brain — Operating Manual

> **Automated ingest** uses `INGEST.md` (slim ingest-only reference) instead of this file to reduce token usage. If you update the ingest pipeline, naming conventions, frontmatter schema, or confidence rules here, mirror those changes in `INGEST.md`.

This is a personal LLM-maintained wiki covering the domains listed under [Domains](#domains). Sources come from many voices — X posts and threads, YouTube videos, podcast transcripts, and occasional images.

You (the LLM) are the wiki's sole maintainer. The owner curates sources and asks questions. They do not write wiki pages — you do.

> **Setting this vault up?** Run `/setup` in Claude Code (see `.claude/commands/setup.md`), or `scripts/setup.ps1` in PowerShell.

---

## Automation

Two Windows Task Scheduler tasks run automatically once `scripts/setup.ps1` registers them. You do not need to trigger them — they run headlessly via `claude --print`.

**`SecondBrain-NightlyIngest`** — runs daily at the time chosen in setup (fires on next login if the computer was off):
- Script: `scripts/nightly-ingest.ps1`
- Detects new raw files by comparing against `raw/.ingested` (manifest file, one raw filename per line)
- **Two-pass routing** — the runner splits new files into two groups and runs each separately:
  - **Standard pass** (articles, videos, podcasts): full `INGEST.md` pipeline on the default model. Full depth.
  - **Newsletter pass** (files tagged `newsletter` or with `TLDR` in the filename): slim `NEWSLETTER.md` pipeline on a cheap model (`haiku`). Writes one rolling weekly digest page per week instead of per-edition source pages — keeps a linked record of every story for minimal tokens.
- After each successful ingest, appends processed filenames to `raw/.ingested`
- Results go to `scripts/logs/nightly-ingest-YYYY-MM-DD.log`

**`SecondBrain-WeeklyLint`** — runs every Sunday (fires on next login if the computer was off):
- Script: `scripts/weekly-lint.ps1`
- Runs the full lint workflow from this file, auto-files any warranted syntheses
- After lint, reads `log.md` for the past 7 days and writes a weekly digest
- Emails the digest if `scripts/.env` has Gmail settings; otherwise saves it to `scripts/logs/digest-YYYY-MM-DD.txt`
- `scripts/.env` is git-ignored. Never copy its contents into the vault.

**The manifest (`raw/.ingested`):**
- Raw files use Obsidian Web Clipper naming (e.g. `2026-05-03T180730-0700--@author--title.md`) — these never match wiki/sources slugs directly
- The manifest tracks ingested files by their exact raw filename, not by slug comparison
- If you manually ingest a file during an interactive session, append its filename to `raw/.ingested` so the nightly runner doesn't re-process it

**If the automation breaks:**
- Check `scripts/logs/` for the most recent log file
- The scripts find Claude Code via `claude` on PATH, falling back to the desktop app's bundled `claude.exe`
- `--verbose` is required alongside `--output-format stream-json`
- All script strings must be ASCII-only (PowerShell 5.1 misreads UTF-8 em dashes)

---

## Domains

<!-- domains:start - scripts/setup.ps1 rewrites this table -->
| Domain | Scope |
|---|---|
| **AI** | New developments, agent building, business ideas in AI |
| **Business** | Strategy, startups, company analysis, industries |
| **Investing & Finance** | Individual stock theses, macro trends, sector highlights |
| **Technology** | Tech outside AI — hardware, software, platforms, infrastructure |
| **Philosophy** | Ideas, ethics, epistemology, frameworks for thinking |
| **Health** | Personal health, longevity, medicine, nutrition, fitness |
| **Geopolitics** | International relations, macro power dynamics, policy |
| **Personal Development** | Behavior change, habit formation, productivity, mindset, psychology of growth |
<!-- domains:end -->

Sources often cross domains. Tag and link to all relevant domain hubs — don't force a single classification.

---

## Layers

```
.
├── CLAUDE.md              ← this file (schema + workflows)
├── index.md               ← content catalog (you maintain)
├── log.md                 ← chronological event log (you append)
├── raw/                   ← IMMUTABLE source material — never edit
│   ├── articles/          ← X posts/threads, blog posts, gists (markdown)
│   ├── videos/            ← YouTube transcripts + metadata
│   ├── podcasts/          ← podcast transcripts
│   └── assets/            ← downloaded images, graphs, screenshots
├── wiki/                  ← LLM-generated pages — you own this
│   ├── overview.md        ← top-level orientation, refreshed periodically
│   ├── domains/           ← one hub page per domain (entry points), e.g. ai.md
│   ├── entities/          ← people, orgs, companies, products
│   ├── concepts/          ← ideas, techniques, frameworks, theories
│   ├── sources/           ← one summary per ingested source
│   └── syntheses/         ← cross-source analyses, comparisons, theses
└── templates/             ← page templates
```

**Strict rules:**
- Never modify anything in `raw/`. It is read-only truth.
- Every wiki page is yours to create, edit, merge, or delete as knowledge sharpens.
- When uncertain about a fact, cite the source and flag uncertainty rather than smoothing it over.

---

## Default mode: low-interaction ingest

The owner typically wants to **drop a source in and walk away**. Don't ask clarifying questions before ingesting unless the source is genuinely ambiguous (e.g. wrong file, broken transcript). Default behavior:

1. Read the source end-to-end.
2. Run the full ingest pipeline (below) without asking.
3. Report back with a **short summary**: what was added, which pages were touched, any flags.

If the owner wants the interactive version, they'll say so — "let's discuss first", "walk me through it", "what do you think about X". In that case, pause after reading and discuss before writing.

---

## Workflows

### 1. Ingest

Trigger: the owner drops a file in `raw/` (or pastes content) and says "ingest this", "add this", names a file, or just gives a URL/transcript.

Steps:
1. **Locate or save the raw source.** If pasted, save to the right `raw/` subfolder with naming convention (below). If already there, note the path.
2. **Read it fully.** Note: people, orgs, companies, dates, technical concepts, claims, opinions, domain(s) it touches.
3. **Identify domains.** Tag the source with 1–3 domains from the list above. A piece that spans two domains gets both.
4. **Create a source page** in `wiki/sources/`. One per source.
5. **Update domain hub pages.** Add the source to the "Recent sources" section of each relevant `wiki/domains/` page. Update the domain's evolving synthesis if the source adds something meaningful.
6. **Update entity pages.** For every notable person, org, or company, create or update a page in `wiki/entities/`. Cite the source.
7. **Update concept pages.** For every significant idea or framework, create or update a page in `wiki/concepts/`. Cite the source.
8. **Cross-link.** Use Obsidian wikilinks: `[[entity-name]]`, `[[concept-name]]`, `[[domain-hub]]`. Every notable reference gets a link.
9. **Flag contradictions / supersessions.** If a new source disagrees with an existing claim: (a) if the new source clearly overrides the old one, use `> [!superseded]` on the old claim and update the concept's `confidence` and `last_verified`; (b) if both claims are live and unresolved, use `> [!warning] Contradiction`. Note either case in the report. On ingest, also update `confidence` per the scoring rules above.
10. **Update [index.md](index.md).** Add the new source and any new entity/concept pages.
11. **Append to [log.md](log.md).** One entry, parseable prefix format (see Logging).
12. **Report.** Short summary: ingested X, created N pages, updated M, flags: …

A typical ingest touches 5–15 wiki files.

### 2. Query

Trigger: the owner asks a question (not an ingest command).

Steps:
1. Read [index.md](index.md) to find candidate pages.
2. Drill into 3–8 relevant wiki pages.
3. Answer with citations linking to wiki and source pages.
4. **Crystallization check.** After answering, evaluate: did this response produce real synthesis — a new connection across sources, a resolved contradiction, a cross-domain pattern? If yes, **file it automatically** as `wiki/syntheses/kebab-slug.md` without asking. File the synthesis, update index.md and the relevant domain hub(s), and note it in the response. Only skip if the answer is a simple factual lookup with no synthesis value. (Old behavior was "offer to file" — this is now automatic for high-synthesis responses.)

### 3. Lint

Trigger: the owner says "lint", "health check", "audit the wiki".

Check for:
- **Contradictions** between pages.
- **Stale claims** superseded by newer sources.
- **Orphan pages** with no inbound wikilinks.
- **Implicit concepts** mentioned across pages but lacking their own page — promote them.
- **Missing cross-references.**
- **Domain imbalances** — domains with thin coverage where the owner has shown interest; suggest sources to find.
- **Staleness candidates** — concept pages where `last_verified` is > 90 days ago AND `confidence < 0.75`. List these explicitly; they need re-verification before being relied on.
- **Tier graduation candidates** — `working` concepts that now have 2+ sources (should become `episodic`); `episodic` concepts cited cross-domain (should become `semantic`).
- **Quality score** — for each concept page, compute a lightweight score: `(sources × 0.3) + (confidence × 0.4) + (cross_refs × 0.1) + (has_relationships_section × 0.2)`. Pages scoring below 0.4 are enrichment candidates.
- **Synthesis opportunities** — scan for clusters of 3+ sources or 2+ concept pages that share a meaningful tension, convergence, or cross-domain pattern not yet captured in `wiki/syntheses/`. If adequate material exists, **write the synthesis automatically** as part of the lint run (same auto-filing rule as crystallization in Query). Do not ask first. List each synthesis filed in the lint report.

Output a punch list grouped by severity. Confirm before large structural changes (renames, merges, deletions).

---

## Domain hub page structure

Each `wiki/domains/<domain>.md` follows this shape:

```
# <Domain>

One-line description of what this domain covers in this wiki.

## Overview
Evolving synthesis of what the wiki has learned about this domain so far.
Update this paragraph with every significant ingest.

## Key themes
Bullet list of recurring themes, updated as they emerge.

## Key entities
[[entity-1]], [[entity-2]], ...

## Key concepts
[[concept-1]], [[concept-2]], ...

## Recent sources (newest first)
- YYYY-MM-DD — [[source-page]] — one-line hook
```

---

## Naming conventions

**Files in `raw/`:**
- `raw/articles/YYYY-MM-DD-short-slug.md`
- `raw/videos/YYYY-MM-DD-short-slug.md`
- `raw/podcasts/YYYY-MM-DD-show-episode.md`
- `raw/assets/YYYY-MM-DD-slug-descriptor.png`

If the exact date is unknown, use the year and note "approx" in the source page.

**Files in `wiki/`:**
- `wiki/entities/firstname-lastname.md` or `wiki/entities/org-name.md`
- `wiki/concepts/kebab-case-slug.md`
- `wiki/sources/YYYY-MM-DD-short-slug.md` (mirror the raw file slug)
- `wiki/syntheses/kebab-case-slug.md`

Lowercase, hyphens, no spaces.

---

## Page conventions

Every wiki page begins with YAML frontmatter:

```yaml
---
type: source | entity | concept | synthesis | domain | overview
created: YYYY-MM-DD
updated: YYYY-MM-DD
sources: 0
domains: []            # 1-3 slugs from the Domains table
tags: []
---
```

**Concept pages** carry three additional fields:

```yaml
confidence: 0.75        # 0.0–1.0; how well-corroborated is the core claim
last_verified: YYYY-MM-DD
tier: working           # working | episodic | semantic | procedural
```

**Entity pages** carry one additional field:

```yaml
last_verified: YYYY-MM-DD
```

`domains` is a list of 1–3 values from the domain list. Update `updated`, `sources`, and `last_verified` on every touch.

### Confidence scoring rules

| Situation | Effect |
|---|---|
| New concept, 1 source | Start at 0.60 (speculative claim) or 0.75 (factual/scientific) |
| Each additional corroborating source | +0.08 |
| Contradicting source found | −0.15 |
| Cross-domain corroboration (2+ domains citing the same claim) | +0.05 bonus |
| Lint surfaces page as stale (last_verified > 90 days + confidence < 0.75) | Flag for re-verification; do not auto-lower without human review |

**Ceiling:** 0.95. No claim in a living wiki is certain.

### Consolidation tier rules

| Tier | Criteria |
|---|---|
| `working` | 1 source; claim is recent, speculative, or not yet tested against other knowledge |
| `episodic` | 2+ sources OR well-established fact from 1 authoritative source; domain-specific |
| `semantic` | 3+ sources AND cross-domain generalization; the claim has been tested and holds across contexts |
| `procedural` | Describes a repeatable workflow, method, or protocol regardless of source count |

Graduate a concept upward during ingest when the new source provides corroboration. Downgrade only during lint if contradictions erode confidence below the tier threshold.

Use Obsidian features liberally:
- `[[wikilinks]]` for every reference to another page.
- `> [!note]`, `> [!warning]`, `> [!quote]` callouts.
- `> [!superseded]` callout (see below) for overridden claims.
- Tables for comparisons.
- Block quotes with citations: `> "quote text" — [[source-page]]`.

### Supersession convention

When a new source contradicts or updates an existing claim, **do not delete** the old claim. Timestamp it as superseded:

```markdown
> [!superseded] Superseded YYYY-MM-DD
> Prior claim: [exact old text]. Source: [[old-source]].
> Superseded by [[new-source]]: [new claim below or in next paragraph].
```

This preserves intellectual history. The `> [!warning] Contradiction` callout is for *unresolved* tension between two live claims. `> [!superseded]` is for resolved supersession where the new claim wins.

### Typed Relationships section

Concept pages include a `## Relationships` section with explicitly typed links:

```markdown
## Relationships

- **INFLUENCES** → [[concept-x]] — [one-line explanation]
- **CONTRADICTS** → [[concept-y]] — [one-line explanation]
- **PART_OF** → [[concept-z]] — [one-line explanation]
- **AUTHORED_BY** → [[entity]] — [one-line explanation]
- **PRECEDES** → [[concept-w]] — [one-line explanation]
```

Valid relationship types: `INFLUENCES`, `CONTRADICTS`, `PART_OF`, `AUTHORED_BY`, `EXTENDS`, `PRECEDES`, `CORROBORATES`.

Add this section when a concept has 2+ meaningful typed connections. Skip for thin single-source pages where `## Related concepts` is sufficient.

---

## Logging

Append to [log.md](log.md) on every ingest, lint, or filed synthesis. Format:

```
## [YYYY-MM-DD] ingest | Short Title
Domains: ai, business. Pages touched: N created, M updated. Tokens: X in / X out | Cost: $X.XX. Notes: …
```

Always include the `Tokens:` line. For automated runs the token count is captured by the task runner; for manual sessions, report the approximate usage from the session.

Event types: `ingest`, `query`, `lint`, `synthesis`, `restructure`.

---

## Indexing

[index.md](index.md) is the catalog. Structure:

- **Overview** — link to `wiki/overview.md`.
- **Domains** — links to each domain hub.
- **Entities** — alphabetical, one line each.
- **Concepts** — alphabetical, one line each.
- **Syntheses** — newest first, one-line hook.
- **Sources** — newest first, with domain tags: `YYYY-MM-DD — [[source-page]] — [ai, business] — one-line summary`.

---

## Source handling by type

**X posts/threads:** capture handle, date, URL, full text. Quote-tweets note the parent.

**YouTube:** capture channel, title, URL, publish date, duration, full transcript. Preserve chapter markers as H3 headings in the raw file.

**Podcasts:** capture show name, episode title, URL, date, speakers, full transcript if available.

**Images/charts:** save to `raw/assets/`. Read the source text first, then view images separately to pull additional context. Describe image content on the relevant wiki page.

---

## Reporting style

After ingest (keep under 12 lines):

```
Ingested: <source title>
Domains: <list>
Source page: [[wiki/sources/...]]
New pages: <list>
Updated pages: <list>
Flags: <contradictions, gaps, follow-ups — or "none">
```

After query: answer + optional "Worth filing as a synthesis? (y/n)".

After lint: punch list grouped by severity.

---

## What to avoid

- Don't ask permission on every micro-edit during ingest. Run the pipeline.
- Don't write filler ("This page covers…"). Pages are reference material.
- Don't duplicate raw text. Summaries paraphrase; quotes are explicit and cited.
- Don't over-fragment. A concept page with sub-headings beats five tiny pages.
- Don't under-fragment. Once a sub-topic has 3+ sources, promote it to its own page.
- Don't editorialize. The wiki reflects sources; synthesis pages capture cross-source patterns and tensions, not opinions. File syntheses automatically when material warrants it (lint, query crystallization) — don't wait to be asked.
