# Second Brain

An Obsidian vault that Claude Code maintains for you. You clip articles, threads, videos and podcast transcripts into `raw/`. Every night, Claude reads what's new and files it into a linked wiki: one page per source, plus pages for the people and ideas they mention, hub pages for each topic you care about, and cross-links between all of it. Once a week it checks the whole wiki for contradictions and gaps, writes up patterns it finds across sources, and can email you a digest.

You never write wiki pages. You choose what goes in and ask questions; Claude does the filing.

It's based on Andrej Karpathy's "LLM wiki" idea, with a few additions:
- **Confidence and tiers.** Each idea page carries a confidence score that rises as more sources agree and falls when one disagrees.
- **Supersession, not deletion.** When a newer source overrides an old claim, the old claim stays, marked as superseded, so you can see how your understanding changed.
- **Two-speed ingest.** Daily newsletters (like TLDR) go through a cheap, light pass into one weekly digest page, so they don't eat your usage. Everything else gets the full treatment.
- **Typed links.** Idea pages say how they relate: influences, contradicts, part of, extends.

## What you need

- **Windows** (the schedule uses Task Scheduler; on a Mac, ask Claude Code to adapt the two scripts to launchd).
- **[Obsidian](https://obsidian.md)**, free.
- **[Claude Code](https://claude.com/claude-code)**, signed in. Check that `claude` runs in a terminal.
- **Optional:** the [Obsidian Web Clipper](https://obsidian.md/clipper) browser extension, to save pages straight into `raw/articles`.

## 1. Get the vault

```bash
git clone https://github.com/<your-username>/second-brain-kit.git "Second Brain"
```

Or download the ZIP from GitHub and unzip it. In Obsidian, choose **Open folder as vault** and pick the folder.

**Your notes are personal.** If you keep the vault in git, make the repo private. The kit ignores your setup and email settings, but not your notes.

## 2. Make it yours

In PowerShell, from the vault folder:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\setup.ps1
```

It asks:
- **your domains**, the topics the wiki is organized around (it starts with AI, Business, Investing & Finance, Technology, Philosophy, Health, Geopolitics and Personal Development; keep, rename, drop or add);
- a one-line scope for each, which tells Claude what belongs where;
- what time the nightly ingest runs and which day the weekly lint runs;
- whether to register both in Task Scheduler;
- whether to email you the weekly digest, and if so your Gmail and an app password.

Then it writes the Domains table into `CLAUDE.md` and `INGEST.md`, creates a hub page per domain, and starts `index.md`, `log.md` and `wiki/overview.md`. Your answers go in `setup.json`; the email password goes in `scripts\.env`. **Both are git-ignored.**

**Set up with Claude Code instead:** open the folder in Claude Code and type `/setup`. It asks the same questions in conversation.

## 3. Use it

1. Clip something into `raw/articles` (or paste a YouTube transcript into `raw/videos`).
2. Wait for the nightly run, or run it now:
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\nightly-ingest.ps1
   ```
   Add `-DryRun` to see what it would ingest without calling Claude.
3. Open `index.md` in Obsidian, or the graph view, to see what it built.
4. Ask questions in Claude Code from the vault folder: "what do my sources say about X?" Good answers get filed as synthesis pages automatically.

Each run logs what it did, the tokens it used and the cost to `scripts\logs\`. A typical article touches 5 to 15 wiki pages.

**Newsletters:** a file with `TLDR` in its name, or a `newsletter` tag in its frontmatter, takes the light path. Everything else gets the full ingest.

## How it works

| File | Role |
|---|---|
| `CLAUDE.md` | The full operating manual: schema, workflows (ingest, query, lint), page conventions, confidence rules. Claude reads it in every interactive session. |
| `INGEST.md` | A slimmer copy of just the ingest rules, so the nightly run spends fewer tokens. |
| `NEWSLETTER.md` | The light pipeline for daily newsletters. |
| `templates/` | Page shapes for sources, entities, concepts and syntheses. |
| `scripts/nightly-ingest.ps1` | Finds raw files not yet in `raw/.ingested`, splits newsletters from everything else, runs Claude headlessly on each group, and records only the files whose pass succeeded. |
| `scripts/weekly-lint.ps1` | Runs the lint workflow, files syntheses, and emails or saves the digest. |
| `raw/` | Your sources. Claude never edits them. |
| `wiki/` | Claude's pages. |

The scheduled runs use `claude --print --dangerously-skip-permissions`, which lets Claude edit files in the vault without asking. Read the two scripts before you schedule them. They only point Claude at this folder.

## Changing things later

- **Domains:** rerun `scripts\setup.ps1`. Hub pages you already have are kept.
- **Models:** the top of `nightly-ingest.ps1` sets the newsletter model (`haiku`) and lets you pin one for full ingests.
- **Rules:** edit `CLAUDE.md`. If you change ingest rules, mirror them in `INGEST.md`.
- **Turn off the schedule:** delete the two `SecondBrain-*` tasks in Task Scheduler.

## License

MIT
