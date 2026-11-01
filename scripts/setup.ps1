# setup.ps1 -- Make this vault yours: domains, schedule, optional weekly email.
#
#   powershell -ExecutionPolicy Bypass -File scripts\setup.ps1            asks questions, saves setup.json, applies it
#   powershell -ExecutionPolicy Bypass -File scripts\setup.ps1 -Apply     skips the questions, applies setup.json as-is
#                                                                         (this is what Claude Code's /setup runs)
#   add -NoSchedule to either to skip registering the Task Scheduler tasks
#
# Writes: setup.json (git-ignored), the Domains table in CLAUDE.md and INGEST.md, one hub page per
# domain, starter index.md / log.md / wiki/overview.md, scripts/.env (git-ignored, only if you want email).
# Keep this file ASCII-only: Windows PowerShell 5.1 misreads UTF-8 punctuation.

param([switch]$Apply, [switch]$NoSchedule)
$ErrorActionPreference = "Stop"

$Vault     = Split-Path $PSScriptRoot -Parent
$SetupFile = Join-Path $Vault "setup.json"
$EnvFile   = Join-Path $PSScriptRoot ".env"
$Utf8      = New-Object System.Text.UTF8Encoding $false

function Read-Utf8([string]$p)          { [IO.File]::ReadAllText($p, [Text.Encoding]::UTF8) }
function Write-Utf8([string]$p, [string]$s) { [IO.File]::WriteAllText($p, $s, $Utf8) }
function Write-IfMissing([string]$rel, [string]$s) {
    $p = Join-Path $Vault $rel
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Force -Path (Split-Path $p) | Out-Null; Write-Utf8 $p $s; Write-Host "  wrote $rel" }
}
function Slug([string]$s) { (($s.ToLower() -replace '&', 'and') -replace '[^a-z0-9]+', '-').Trim('-') }
function Ask([string]$q, [string]$cur) {
    $a = Read-Host ($(if ($cur) { "$q [$cur]" } else { $q }))
    if ([string]::IsNullOrWhiteSpace($a)) { return $cur } else { return $a.Trim() }
}
function AskYes([string]$q, [bool]$cur) {
    $a = Ask "$q (y/n)" $(if ($cur) { "y" } else { "n" })
    return $a.ToLower().StartsWith("y")
}

# ---------- defaults, then anything saved ----------
$defaults = [ordered]@{
    domains = @(
        [ordered]@{ name = "AI";                   scope = "New developments, agent building, business ideas in AI" },
        [ordered]@{ name = "Business";             scope = "Strategy, startups, company analysis, industries" },
        [ordered]@{ name = "Investing & Finance";  scope = "Individual stock theses, macro trends, sector highlights" },
        [ordered]@{ name = "Technology";           scope = "Tech outside AI: hardware, software, platforms, infrastructure" },
        [ordered]@{ name = "Philosophy";           scope = "Ideas, ethics, epistemology, frameworks for thinking" },
        [ordered]@{ name = "Health";               scope = "Personal health, longevity, medicine, nutrition, fitness" },
        [ordered]@{ name = "Geopolitics";          scope = "International relations, macro power dynamics, policy" },
        [ordered]@{ name = "Personal Development"; scope = "Behavior change, habit formation, productivity, mindset" }
    )
    ingestTime = "23:00"
    lintDay    = "Sunday"
    schedule   = $true
    emailTo    = ""
}
$s = $defaults
if (Test-Path $SetupFile) {
    $saved = Read-Utf8 $SetupFile | ConvertFrom-Json
    foreach ($k in @($defaults.Keys)) { if ($null -ne $saved.$k) { $s[$k] = $saved.$k } }
}

# ---------- questions ----------
if (-not $Apply) {
    Write-Host "Second Brain setup. Press Enter to keep the value in [brackets].`n"
    $names = ($s.domains | ForEach-Object { $_.name }) -join ", "
    $answer = Ask "Your domains, comma-separated" $names
    $picked = @($answer -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $list = @()
    foreach ($n in $picked) {
        $old = $s.domains | Where-Object { $_.name -eq $n } | Select-Object -First 1
        $scope = Ask "  One line on what goes in '$n'" $(if ($old) { $old.scope } else { "" })
        $list += [ordered]@{ name = $n; scope = $scope }
    }
    $s.domains = $list

    do { $s.ingestTime = Ask "Nightly ingest time, 24h HH:mm" $s.ingestTime } until ($s.ingestTime -match '^([01]\d|2[0-3]):[0-5]\d$')
    do { $s.lintDay = Ask "Weekly lint day" $s.lintDay } until ([enum]::GetNames([DayOfWeek]) -contains $s.lintDay)
    $s.schedule = AskYes "Register both tasks in Windows Task Scheduler now?" ([bool]$s.schedule)

    if (AskYes "Email yourself the weekly digest (needs a Gmail app password)?" ([bool]$s.emailTo)) {
        $s.emailTo = Ask "  Send the digest to" $s.emailTo
        $from = Ask "  Gmail address to send from" $s.emailTo
        Write-Host "  Make an app password at https://myaccount.google.com/apppasswords (2-step verification required)."
        $sec = Read-Host "  Paste the 16-character app password (hidden)" -AsSecureString
        $pw = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
        Write-Utf8 $EnvFile "# Git-ignored. Used only by weekly-lint.ps1 to send the digest.`nGMAIL_FROM=$from`nGMAIL_TO=$($s.emailTo)`nGMAIL_APP_PASSWORD=$($pw -replace '\s', '')`n"
        Write-Host "  Saved email settings to scripts\.env (git-ignored)."
    } else {
        $s.emailTo = ""
    }
    Write-Utf8 $SetupFile (($s | ConvertTo-Json -Depth 5) + "`n")
    Write-Host "`nSaved your answers to setup.json.`n"
}
if (-not $s.domains -or @($s.domains).Count -eq 0) { throw "setup.json needs at least one domain." }

# ---------- domains: table in both manuals, one hub page each ----------
$rows = ($s.domains | ForEach-Object { "| **$($_.name)** | $($_.scope) |" }) -join "`n"
$table = "| Domain | Scope |`n|---|---|`n$rows`n"
foreach ($f in @("CLAUDE.md", "INGEST.md")) {
    $p = Join-Path $Vault $f
    $t = Read-Utf8 $p
    $re = '(?s)(<!-- domains:start[^\n]*-->\r?\n).*?(<!-- domains:end -->)'
    if ($t -notmatch $re) { throw "$f is missing the <!-- domains:start --> / <!-- domains:end --> markers." }
    Write-Utf8 $p ([regex]::Replace($t, $re, { param($m) $m.Groups[1].Value + $table + $m.Groups[2].Value }))
    Write-Host "Wrote the Domains table in $f."
}
$today = Get-Date -Format 'yyyy-MM-dd'
foreach ($d in $s.domains) {
    $slug = Slug $d.name
    Write-IfMissing "wiki\domains\$slug.md" @"
---
type: domain
created: $today
updated: $today
sources: 0
domains: [$slug]
tags: []
---

# $($d.name)

$($d.scope).

## Overview
Nothing ingested yet.

## Key themes

## Key entities

## Key concepts

## Recent sources (newest first)
"@
}

# ---------- starter pages (never overwritten) ----------
$hubLinks = ($s.domains | ForEach-Object { "- [[wiki/domains/$(Slug $_.name)|$($_.name)]] - $($_.scope) (0 sources)" }) -join "`n"
Write-IfMissing "index.md" "# Index`n`nContent catalog. Updated on every ingest. See [CLAUDE.md](CLAUDE.md) for schema and [log.md](log.md) for event history.`n`n## Overview`n`n- [[wiki/overview|Overview]] - top-level map of the wiki.`n`n## Domains`n`n$hubLinks`n`n## Entities`n`n## Concepts`n`n## Syntheses`n`n## Sources`n"
Write-IfMissing "log.md" "# Log`n`nChronological event log. Newest entries at the bottom.`n`n## [$today] restructure | Vault created from second-brain-kit`n"
Write-IfMissing "wiki\overview.md" "---`ntype: overview`ncreated: $today`nupdated: $today`nsources: 0`ndomains: []`ntags: []`n---`n`n# Overview`n`nNothing ingested yet. Clip a few articles into raw/articles and run scripts\nightly-ingest.ps1.`n"
Write-IfMissing "raw\.ingested" ""

# ---------- Task Scheduler ----------
if ($s.schedule -and -not $NoSchedule) {
    $ps = (Get-Command powershell.exe).Source
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopIfGoingOnBatteries -AllowStartIfOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 2)
    $nightly = New-ScheduledTaskAction -Execute $ps -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\nightly-ingest.ps1`""
    $weekly  = New-ScheduledTaskAction -Execute $ps -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\weekly-lint.ps1`""
    Register-ScheduledTask -TaskName "SecondBrain-NightlyIngest" -Action $nightly -Settings $settings -Force `
        -Trigger (New-ScheduledTaskTrigger -Daily -At $s.ingestTime) -Description "Ingest new clippings into the Second Brain vault at $Vault" | Out-Null
    Register-ScheduledTask -TaskName "SecondBrain-WeeklyLint" -Action $weekly -Settings $settings -Force `
        -Trigger (New-ScheduledTaskTrigger -Weekly -DaysOfWeek $s.lintDay -At "10:00") -Description "Lint the Second Brain vault and write the weekly digest" | Out-Null
    Write-Host "Registered SecondBrain-NightlyIngest (daily $($s.ingestTime)) and SecondBrain-WeeklyLint ($($s.lintDay) 10:00)."
} else {
    Write-Host "Skipped Task Scheduler. Run scripts\nightly-ingest.ps1 by hand, or rerun setup to register the tasks."
}

Write-Host "`nDone. Open this folder as a vault in Obsidian, clip something into raw\articles, then run:"
Write-Host "  powershell -ExecutionPolicy Bypass -File scripts\nightly-ingest.ps1"
