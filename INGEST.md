# Ingest Reference

Automated ingest pipeline reference. Full operating manual (query, lint, schema history) in CLAUDE.md.

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

Tag each source with 1–3 domains. Sources that cross domains get all relevant tags.

---

## Directory structure

```
raw/articles/    ← X posts, blog posts, gists (read-only)
raw/videos/      ← YouTube transcripts (read-only)
raw/podcasts/    ← podcast transcripts (read-only)
raw/assets/      ← images, charts (read-only)
wiki/sources/    ← one page per ingested source (you write)
wiki/entities/   ← people, orgs, companies, products (you write)
wiki/concepts/   ← ideas, frameworks, techniques (you write)
wiki/domains/    ← domain hub pages (you update)
wiki/syntheses/  ← cross-source analyses (you write)
index.md         ← content catalog (you update)
log.md           ← event log (you append)
```

Never modify anything in `raw/`. It is read-only truth.

---

## Ingest pipeline

For each new raw file:

1. **Read the source end-to-end.** Note: people, orgs, companies, dates, technical concepts, claims, opinions, domains.
2. **Identify domains.** Tag with 1–3 domains from the table above.
3. **Create a source page** in `wiki/sources/YYYY-MM-DD-slug.md`.
4. **Update domain hub pages.** Add to "Recent sources" in each relevant `wiki/domains/` page. Update the overview synthesis if the source adds something meaningful.
5. **Update entity pages.** Create or update a page in `wiki/entities/` for every notable person, org, or company. Cite the source.
6. **Update concept pages.** Create or update a page in `wiki/concepts/` for every significant idea or framework. Cite the source.
7. **Cross-link.** Use Obsidian wikilinks: `[[entity-name]]`, `[[concept-name]]`, `[[domain-hub]]`. Every notable reference gets a link.
8. **Flag contradictions / supersessions.** New source overrides old claim → `> [!superseded]` on the old claim, update confidence and last_verified. Unresolved tension → `> [!warning] Contradiction`.
9. **Update index.md.** Add new source and any new entity/concept pages.
10. **Append to log.md.** One entry per source in the format below.
11. **Report.** Ingested X, created N pages, updated M, flags: …

Do not ask for confirmation. Work through all files before stopping.

---

## Source handling by type

**X posts/threads:** capture handle, date, URL, full text. Note quote-tweet parents.
**YouTube:** capture channel, title, URL, publish date, duration, transcript. Preserve chapter markers as H3 headings.
**Podcasts:** capture show name, episode title, URL, date, speakers, transcript if available.
**Images/charts:** describe content; save context from surrounding source text.
**Newsletters (TLDR, etc.):** do NOT use this full pipeline. Newsletters run a separate lightweight path — see `NEWSLETTER.md`. In short: one rolling **weekly digest page** (`wiki/sources/YYYY-Www-newsletters.md`), one H2 per edition, one bullet per story with its link. No per-edition source pages, no new entity/concept pages, no domain-hub updates. Only thread a major recurring signal (frontier model release, >$1B funding/valuation, major geopolitical move) into an **already-existing** entity/concept page. The automated runner sends newsletters through this path on a cheap model; follow `NEWSLETTER.md` for interactive newsletter ingests too.

---

## Naming conventions

- `wiki/sources/YYYY-MM-DD-short-slug.md` — mirrors the raw file slug
- `wiki/entities/firstname-lastname.md` or `wiki/entities/org-name.md`
- `wiki/concepts/kebab-case-slug.md`
- `wiki/syntheses/kebab-case-slug.md`

Lowercase, hyphens, no spaces.

---

## Page frontmatter

Every wiki page:
```yaml
---
type: source | entity | concept | synthesis | domain
created: YYYY-MM-DD
updated: YYYY-MM-DD
sources: 0
domains: []   # 1-3 slugs from the Domains table
tags: []
---
```

Concept pages add:
```yaml
confidence: 0.75
last_verified: YYYY-MM-DD
tier: working
```

Entity pages add:
```yaml
last_verified: YYYY-MM-DD
```

Update `updated`, `sources`, and `last_verified` on every touch.

---

## Confidence scoring

| Situation | Effect |
|---|---|
| New concept, 1 source | 0.60 (speculative) or 0.75 (factual/scientific) |
| Each corroborating source | +0.08 |
| Contradicting source | −0.15 |
| Cross-domain corroboration | +0.05 bonus |

Ceiling: 0.95.

## Consolidation tiers

| Tier | Criteria |
|---|---|
| `working` | 1 source; speculative or untested |
| `episodic` | 2+ sources OR 1 authoritative source; domain-specific |
| `semantic` | 3+ sources AND cross-domain generalization |
| `procedural` | Repeatable workflow or protocol, regardless of source count |

Graduate upward during ingest when a new source corroborates. Downgrade only during lint.

---

## Supersession convention

```markdown
> [!superseded] Superseded YYYY-MM-DD
> Prior claim: [exact old text]. Source: [[old-source]].
> Superseded by [[new-source]]: [new claim].
```

Use `> [!warning] Contradiction` for unresolved tension between two live claims.

---

## Typed relationships

Add a `## Relationships` section to concept pages with 2+ meaningful connections:

```markdown
## Relationships
- **INFLUENCES** → [[concept-x]] — one-line explanation
- **CONTRADICTS** → [[concept-y]] — one-line explanation
- **PART_OF** → [[concept-z]] — one-line explanation
- **AUTHORED_BY** → [[entity]] — one-line explanation
- **PRECEDES** → [[concept-w]] — one-line explanation
```

Valid types: `INFLUENCES`, `CONTRADICTS`, `PART_OF`, `AUTHORED_BY`, `EXTENDS`, `PRECEDES`, `CORROBORATES`.

---

## Domain hub structure

```markdown
# Domain Name
One-line description.

## Overview
Evolving synthesis. Update with every significant ingest.

## Key themes
- bullet list

## Key entities
[[entity-1]], [[entity-2]], ...

## Key concepts
[[concept-1]], [[concept-2]], ...

## Recent sources (newest first)
- YYYY-MM-DD — [[source-page]] — [domains] — one-line hook
```

---

## Log entry format

```
## [YYYY-MM-DD] ingest | Source Title
Domains: ai, business. Pages touched: N created, M updated. Tokens: X in / X out | Cost: $X.XX. Notes: …
```

Tokens line is filled in by the task runner for automated ingests.

---

## Index structure

- **Domains** — links to each domain hub with source counts
- **Entities** — alphabetical, one line each with domains and source count
- **Concepts** — grouped by domain, one line each with source count
- **Syntheses** — newest first, one-line hook
- **Sources** — newest first: `YYYY-MM-DD — [[source-page]] — [domains] — one-line summary`
