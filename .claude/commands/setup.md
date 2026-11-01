---
description: Set up this Second Brain vault for a new owner (domains, schedule, optional weekly email)
---

Set this vault up for the person you're talking to. Assume they may never have used a terminal: explain each step in one line before you run it.

1. **Check the basics.** Confirm they're on Windows (if not, offer to adapt `scripts/nightly-ingest.ps1` and `scripts/weekly-lint.ps1` to their OS's scheduler instead of Task Scheduler). Run `claude --version` to confirm Claude Code is on PATH; if it isn't, the scripts fall back to the desktop app's copy.

2. **Interview them** in plain conversation, one topic at a time:
   - What topics they read about. Turn their answer into 4-10 domains, each with a one-line scope. Offer the defaults in `scripts/setup.ps1` as a starting point.
   - What time the nightly ingest should run (default 23:00) and which day the weekly lint should run (default Sunday).
   - Whether to register both runs in Task Scheduler now.
   - Whether they want the weekly digest by email (Gmail only, needs an app password).

3. **Write `setup.json`** in the vault root with this shape, then show it to them:
   ```json
   { "domains": [{ "name": "AI", "scope": "..." }], "ingestTime": "23:00", "lintDay": "Sunday", "schedule": true, "emailTo": "" }
   ```

4. **Apply it:** `powershell -ExecutionPolicy Bypass -File scripts\setup.ps1 -Apply` (add `-NoSchedule` if they said no to Task Scheduler).

5. **Email, if they want it:** never ask them to paste the app password into chat. Have them run `scripts\setup.ps1` (without `-Apply`) in their own terminal and answer only the email questions, keeping their other answers by pressing Enter. It saves the password to `scripts\.env`, which is git-ignored.

6. **Try it:** help them clip or paste one article into `raw/articles`, run `powershell -ExecutionPolicy Bypass -File scripts\nightly-ingest.ps1`, then open `index.md` and the new source page in Obsidian together.

7. Tell them where the logs are (`scripts\logs\`) and that `CLAUDE.md` is the rulebook they can edit.
