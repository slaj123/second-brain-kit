# nightly-ingest.ps1 -- Nightly ingest for the Second Brain wiki.
# Registered by setup.ps1 as the SecondBrain-NightlyIngest task. Safe to run by hand any time.
#
# Two-pass design:
#   STANDARD pass   -> full INGEST.md pipeline, default model (full depth). Articles/videos/podcasts.
#   NEWSLETTER pass -> slim NEWSLETTER.md pipeline, cheap model (minimal usage). TLDR-style digests.
# The two passes never touch each other; standard ingest depth is unchanged.
#
# Keep this file ASCII-only: Windows PowerShell 5.1 misreads UTF-8 punctuation.

param([switch]$DryRun)   # -DryRun: list what would be ingested, call nothing

$VaultPath    = Split-Path $PSScriptRoot -Parent
$ManifestPath = Join-Path $VaultPath "raw\.ingested"
$LogDir       = Join-Path $PSScriptRoot "logs"
$LogFile      = Join-Path $LogDir "nightly-ingest-$(Get-Date -Format 'yyyy-MM-dd').log"
$Today        = Get-Date -Format 'yyyy-MM-dd'

# Model config. Empty string = use Claude Code's default model (full depth).
$StandardModel   = ""        # standard sources keep the default model
$NewsletterModel = "haiku"   # newsletters use the cheapest capable model; bump to "sonnet" if summaries feel thin

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Write-Log([string]$msg) {
    $line = "[$(Get-Date -Format 'HH:mm:ss')] $msg"
    $line | Out-File $LogFile -Encoding utf8 -Append
    Write-Host $line
}

# ISO week number (PS 5.1 lacks System.Globalization.ISOWeek)
function Get-IsoWeek([datetime]$d) {
    $cal = [System.Globalization.CultureInfo]::InvariantCulture.Calendar
    $dow = $cal.GetDayOfWeek($d)
    if ($dow -ge [DayOfWeek]::Monday -and $dow -le [DayOfWeek]::Wednesday) { $d = $d.AddDays(3) }
    return $cal.GetWeekOfYear($d, [System.Globalization.CalendarWeekRule]::FirstFourDayWeek, [DayOfWeek]::Monday)
}

# A new raw file is a newsletter ONLY on a high-confidence signal:
#   (a) "TLDR" in the filename, OR
#   (b) a "newsletter" tag inside the frontmatter tags: block (NOT the source URL or body).
# Bias is deliberately toward the full-depth standard path: misrouting a newsletter to
# standard just costs tokens once; misrouting an article to the light path loses depth.
function Test-IsNewsletter($item) {
    if ($item.Name -match 'TLDR') { return $true }
    $full = Join-Path $VaultPath ($item.RelPath -replace '/', '\')
    $head = Get-Content $full -TotalCount 25 -ErrorAction SilentlyContinue
    $inTags = $false
    foreach ($l in $head) {
        if ($l -match '^\s*tags:\s*(.*)$') {
            $inTags = $true
            if ($matches[1].Trim() -and $l -match '(?i)newsletter') { return $true }  # inline list form
            continue
        }
        if ($inTags) {
            if ($l -match '^\s*-\s') {                       # a tag list item
                if ($l -match '(?i)newsletter') { return $true }
            } elseif ($l -match '^\S') {                     # next top-level key -> tags block ended
                $inTags = $false
            }
        }
    }
    return $false
}

# Claude Code on PATH first, then the desktop app's bundled copy (newest version).
function Find-Claude {
    $cmd = Get-Command claude -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }
    return Get-Item (Join-Path $env:APPDATA "Claude\claude-code\*\claude.exe") -ErrorAction SilentlyContinue |
        Sort-Object { try { [version]$_.Directory.Name } catch { [version]"0.0.0" } } -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}

# Run one Claude pass; return text + token/cost telemetry.
function Invoke-ClaudePass {
    param([string]$Prompt, [string]$Model)
    $modelArgs = @()
    if ($Model) { $modelArgs = @("--model", $Model) }

    $raw = $Prompt | & $ClaudeExe --print --dangerously-skip-permissions --verbose `
        --add-dir $VaultPath @modelArgs --output-format stream-json 2>&1

    $text = @(); $inTok = 0; $outTok = 0; $cost = 0.0; $ok = $false
    foreach ($line in $raw) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
            $e = $line | ConvertFrom-Json -ErrorAction Stop
            if ($e.type -eq "assistant") {
                foreach ($b in $e.message.content) { if ($b.type -eq "text") { $text += $b.text } }
            } elseif ($e.type -eq "result") {
                $ok = -not $e.is_error
                if ($e.usage)          { $inTok = $e.usage.input_tokens + $e.usage.cache_creation_input_tokens + $e.usage.cache_read_input_tokens; $outTok = $e.usage.output_tokens }
                if ($e.total_cost_usd) { $cost  = [double]$e.total_cost_usd }
            }
        } catch { $text += $line }
    }
    return [PSCustomObject]@{ Text = ($text -join ""); In = $inTok; Out = $outTok; Cost = $cost; Ok = $ok }
}

Write-Log "=== Nightly ingest started ==="

# -- Step 1: Find new raw files via manifest (zero Claude tokens) -------------
$ingested = if (Test-Path $ManifestPath) { @(Get-Content $ManifestPath) } else { @() }

$newFiles = @(@(
    (Join-Path $VaultPath "raw\articles"),
    (Join-Path $VaultPath "raw\videos"),
    (Join-Path $VaultPath "raw\podcasts")
) | ForEach-Object {
    Get-ChildItem $_ -File -Filter *.md -ErrorAction SilentlyContinue |
    Select-Object Name, @{ N='RelPath'; E={ $_.FullName.Replace("$VaultPath\", '').Replace('\', '/') } }
} | Where-Object { $_.Name -notin $ingested })

Write-Log "New files: $($newFiles.Count)"

# -- Step 2a: Nothing new -- log a one-liner and stop -------------------------
if ($newFiles.Count -eq 0) {
    if (-not $DryRun) {
        "`n## [$Today] ingest | Nightly check - no new files`n" |
            Out-File (Join-Path $VaultPath "log.md") -Encoding utf8 -Append
    }
    Write-Log "=== Done (no new files) ==="
    exit 0
}

# -- Step 2b: Partition into standard vs newsletter ---------------------------
$standard    = @($newFiles | Where-Object { -not (Test-IsNewsletter $_) })
$newsletters = @($newFiles | Where-Object {       Test-IsNewsletter $_  })
Write-Log "Standard: $($standard.Count) | Newsletter: $($newsletters.Count)"
if ($DryRun) {
    $standard    | ForEach-Object { Write-Log "  standard:   $($_.RelPath)" }
    $newsletters | ForEach-Object { Write-Log "  newsletter: $($_.RelPath)" }
    Write-Log "=== Dry run: nothing ingested ==="
    exit 0
}

# -- Step 3: Locate Claude Code ----------------------------------------------
$ClaudeExe = Find-Claude
if (-not $ClaudeExe) { Write-Log "ERROR: Claude Code not found. Install it, or check that 'claude' runs in a terminal."; exit 1 }
Write-Log "claude: $ClaudeExe"
Set-Location $VaultPath

$done = @()

# -- Step 4: STANDARD pass (full depth, default model) -----------------------
if ($standard.Count -gt 0) {
    $fileList = ($standard | ForEach-Object { "- $($_.RelPath)" }) -join "`n"
    $prompt = "You are maintaining a personal second brain wiki. Vault root is your current working directory.`n" +
        "Read INGEST.md for the schema and pipeline steps.`n`n" +
        "New files to ingest:`n$fileList`n`n" +
        "Run the full ingest pipeline from INGEST.md for each file. Do not ask for confirmation. " +
        "Work through all files before stopping."

    $r = Invoke-ClaudePass -Prompt $prompt -Model $StandardModel
    $r.Text | Out-File $LogFile -Encoding utf8 -Append
    $m = if ($StandardModel) { $StandardModel } else { "default" }
    Write-Log "Standard pass ($m): $($r.In) in / $($r.Out) out | `$$([math]::Round($r.Cost, 4)) | ok=$($r.Ok)"
    if ($r.Ok) { $done += $standard }
}

# -- Step 5: NEWSLETTER pass (lightweight, cheap model) ----------------------
if ($newsletters.Count -gt 0) {
    $week   = "{0}-W{1:00}" -f (Get-Date).Year, (Get-IsoWeek (Get-Date))
    $digest = "wiki/sources/$week-newsletters.md"
    $fileList = ($newsletters | ForEach-Object { "- $($_.RelPath)" }) -join "`n"
    $prompt = "You are maintaining a personal second brain wiki. Vault root is your current working directory.`n" +
        "Read NEWSLETTER.md for the lightweight newsletter pipeline. Spend minimal tokens.`n`n" +
        "Weekly digest page for this batch: $digest`n`n" +
        "Newsletter files:`n$fileList`n`n" +
        "Follow NEWSLETTER.md exactly. Do not run the full INGEST.md pipeline. " +
        "Work through all editions, then stop."

    $r = Invoke-ClaudePass -Prompt $prompt -Model $NewsletterModel
    $r.Text | Out-File $LogFile -Encoding utf8 -Append
    Write-Log "Newsletter pass ($NewsletterModel): $($r.In) in / $($r.Out) out | `$$([math]::Round($r.Cost, 4)) | ok=$($r.Ok)"
    if ($r.Ok) { $done += $newsletters }
}

# -- Step 6: Record only the files whose pass succeeded ----------------------
# (A failed pass leaves its files out of the manifest, so tomorrow's run retries them.)
if ($done.Count -gt 0) {
    $done | ForEach-Object { $_.Name } | Out-File $ManifestPath -Encoding utf8 -Append
}
Write-Log "Manifest updated (+$($done.Count) of $($newFiles.Count) files)"

Write-Log "=== Done ==="
