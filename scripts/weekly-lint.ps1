# weekly-lint.ps1 -- Weekly lint + digest for the Second Brain wiki.
# Registered by setup.ps1 as the SecondBrain-WeeklyLint task (Sundays). Safe to run by hand.
# Emails the digest if scripts/.env has Gmail settings; otherwise saves it to scripts/logs/.
#
# Keep this file ASCII-only: Windows PowerShell 5.1 misreads UTF-8 punctuation.

$VaultPath = Split-Path $PSScriptRoot -Parent
$LogDir    = Join-Path $PSScriptRoot "logs"
$LogFile   = Join-Path $LogDir "weekly-lint-$(Get-Date -Format 'yyyy-MM-dd').log"
$Today     = Get-Date -Format 'yyyy-MM-dd'

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Write-Log([string]$msg) {
    $line = "[$(Get-Date -Format 'HH:mm:ss')] $msg"
    $line | Out-File $LogFile -Encoding utf8 -Append
    Write-Host $line
}

function Save-Digest([string]$body) {
    $path = Join-Path $LogDir "digest-$Today.txt"
    $body | Out-File $path -Encoding utf8
    Write-Log "Digest saved to $path"
}

function Send-Digest([string]$subject, [string]$body) {
    if (-not ($GmailPassword -and $GmailFrom -and $GmailTo)) { Save-Digest $body; return }
    try {
        $smtp = New-Object System.Net.Mail.SmtpClient('smtp.gmail.com', 587)
        $smtp.EnableSsl = $true
        $smtp.Credentials = New-Object System.Net.NetworkCredential($GmailFrom, $GmailPassword)
        $smtp.Send((New-Object System.Net.Mail.MailMessage($GmailFrom, $GmailTo, $subject, $body)))
        Write-Log "Email sent to $GmailTo"
    } catch {
        Write-Log "Email FAILED: $($_.Exception.Message)"
        Save-Digest $body
    }
}

Write-Log "=== Weekly lint started ==="

# Optional email settings, from the git-ignored scripts/.env (written by setup.ps1).
$envVars = @{}
$envFile = Join-Path $PSScriptRoot ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^([^#=]+?)=(.+)$') { $envVars[$matches[1].Trim()] = $matches[2].Trim() }
    }
}
$GmailPassword = $envVars['GMAIL_APP_PASSWORD']
$GmailFrom     = $envVars['GMAIL_FROM']
$GmailTo       = $envVars['GMAIL_TO']

$ClaudeExe = (Get-Command claude -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if (-not $ClaudeExe) {
    $ClaudeExe = Get-Item (Join-Path $env:APPDATA "Claude\claude-code\*\claude.exe") -ErrorAction SilentlyContinue |
        Sort-Object { try { [version]$_.Directory.Name } catch { [version]"0.0.0" } } -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $ClaudeExe) { Write-Log "ERROR: Claude Code not found. Install it, or check that 'claude' runs in a terminal."; exit 1 }
Write-Log "claude: $ClaudeExe"
Set-Location $VaultPath

$prompt = "You are maintaining a personal second brain wiki. Vault root is your current working directory.`n" +
    "Read CLAUDE.md for the full operating manual.`n`n" +
    "Step 1: Run the complete lint workflow from CLAUDE.md. Check for contradictions, stale claims, orphan pages, " +
    "implicit concepts lacking their own page, missing cross-references, domain imbalances, staleness candidates " +
    "(last_verified > 90 days AND confidence < 0.75), tier graduation candidates, and quality scores below 0.4.`n`n" +
    "Step 2: Scan for synthesis opportunities -- clusters of 3+ sources or 2+ concept pages with unresolved tension " +
    "or cross-domain convergence not yet in wiki/syntheses/. Write any warranted syntheses automatically.`n`n" +
    "Step 3: Apply all standard fixes without asking. Do not rename, merge or delete pages; list those as suggestions.`n`n" +
    "Step 4: Append a full lint entry to log.md with everything found and fixed.`n`n" +
    "Step 5: Read log.md and find all ingest entries from the past 7 days. " +
    "For each ingested source, read its wiki/sources/ page to get the details.`n`n" +
    "Then output exactly the following delimiter on its own line, followed by the weekly digest:`n`n" +
    "=== EMAIL DIGEST ===`n" +
    "Write a plain-text weekly digest with three sections (no markdown, no symbols):`n" +
    "Section 1 - This week: one short paragraph per article ingested (author, key claim, why it matters -- under 40 words each).`n" +
    "Section 2 - Themes: 2-4 sentences on patterns or tensions that emerged across this week's sources.`n" +
    "Section 3 - New syntheses: list any synthesis pages created during this lint run with a one-sentence description each. Write None if no new syntheses."

$rawOut = $prompt | & $ClaudeExe --print --dangerously-skip-permissions --verbose `
    --add-dir $VaultPath --output-format stream-json 2>&1

$text = @(); $inTok = 0; $outTok = 0; $cost = 0.0
foreach ($line in $rawOut) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    try {
        $e = $line | ConvertFrom-Json -ErrorAction Stop
        if ($e.type -eq "assistant") {
            foreach ($b in $e.message.content) { if ($b.type -eq "text") { $text += $b.text } }
        } elseif ($e.type -eq "result") {
            if ($e.usage)          { $inTok = $e.usage.input_tokens + $e.usage.cache_creation_input_tokens + $e.usage.cache_read_input_tokens; $outTok = $e.usage.output_tokens }
            if ($e.total_cost_usd) { $cost  = [double]$e.total_cost_usd }
        }
    } catch { $text += $line }
}

$fullText  = $text -join ""
$parts     = $fullText -split "=== EMAIL DIGEST ===", 2
$logPart   = $parts[0].Trim()
$emailBody = if ($parts.Count -gt 1) { $parts[1].Trim() } else { "No digest generated." }

Write-Log "Lint: $inTok in / $outTok out | `$$([math]::Round($cost, 4))"
$logPart | Out-File $LogFile -Encoding utf8 -Append
Send-Digest "Second Brain Weekly -- $Today" $emailBody

Write-Log "=== Done ==="
