<#
.SYNOPSIS
    Self-check for hark.ps1. Mirrors the assertions in tests/test.sh.

.DESCRIPTION
    Run with:  powershell -NoProfile -File tests/test.ps1

    Like the sh suite, this observes `hark.ps1 test` output (which prints the
    role -> file table before playing) and uses HARK_PLAYER to stand in for
    the audio device, so nothing is ever heard.
#>

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$Hark = Join-Path $Root 'scripts/hark.ps1'
$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("hark-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $Tmp -Force | Out-Null

# Never read the developer's real config, and never make a sound.
$env:HARK_CONF = Join-Path $Tmp 'absent.conf'
$env:HARK_PLAYER = 'Write-Output'

$script:Pass = 0
$script:Fail = 0

function Test-Ok([string]$Name) {
    $script:Pass++
    Write-Host "  ok   $Name"
}

function Test-No([string]$Name, [string]$Expected, [string]$Actual) {
    $script:Fail++
    Write-Host "  FAIL $Name"
    Write-Host "       expected: $Expected"
    Write-Host "       actual:   $Actual"
}

function Assert-Contains([string]$Name, [string]$Needle, [string]$Haystack) {
    if ($Haystack -like "*$Needle*") { Test-Ok $Name }
    else { Test-No $Name "contains '$Needle'" $Haystack }
}

function Assert-Missing([string]$Name, [string]$Needle, [string]$Haystack) {
    if ($Haystack -like "*$Needle*") { Test-No $Name "does NOT contain '$Needle'" $Haystack }
    else { Test-Ok $Name }
}

function Assert-Equals([string]$Name, [string]$Expected, [string]$Actual) {
    if ($Expected -eq $Actual) { Test-Ok $Name }
    else { Test-No $Name $Expected $Actual }
}

function Invoke-Hark {
    param([string[]]$HarkArgs)
    (& powershell -NoProfile -File $Hark @HarkArgs 2>&1 | Out-String).Trim()
}

Write-Host 'hark.ps1 self-check'

# --- presets --------------------------------------------------------------
$env:HARK_PRESET = 'default'
$out = Invoke-Hark @('test')
Assert-Contains 'default/done maps to done.wav' 'done.wav' $out
Assert-Contains 'default/error maps to error.wav' 'error.wav' $out

$env:HARK_PRESET = 'subtle'
$out = Invoke-Hark @('test')
Assert-Contains 'subtle/done maps to subtle-done.wav' 'subtle-done.wav' $out

$env:HARK_PRESET = 'minimal'
$out = Invoke-Hark @('test')
Assert-Contains 'minimal keeps done' 'done -> ' $out
Assert-Missing 'minimal silences error' 'error -> ' $out

$env:HARK_PRESET = 'off'
$out = Invoke-Hark @('test')
Assert-Equals 'off resolves nothing at all' '' $out

$env:HARK_PRESET = 'macos'
$out = Invoke-Hark @('test')
Assert-Contains 'macos/done is Glass' 'Glass.aiff' $out
Assert-Missing 'macos has no bye sound' 'bye -> ' $out

$env:HARK_PRESET = 'nonsense'
$out = Invoke-Hark @('test')
Assert-Contains 'unknown preset behaves as default' 'done.wav' $out

# --- config file ----------------------------------------------------------
Remove-Item Env:\HARK_PRESET
$basic = Join-Path $Tmp 'basic.conf'
"# a comment`nHARK_PRESET=subtle`n" | Set-Content -LiteralPath $basic
$env:HARK_CONF = $basic
$out = Invoke-Hark @('test')
Assert-Contains 'config file selects the preset' 'subtle-done.wav' $out

$env:HARK_PRESET = 'macos'
$out = Invoke-Hark @('test')
Assert-Contains 'environment beats config file' 'Glass.aiff' $out
Remove-Item Env:\HARK_PRESET

$override = Join-Path $Tmp 'override.conf'
"HARK_PRESET=default`nHARK_SOUND_DONE=C:\mine.wav`n" | Set-Content -LiteralPath $override
$env:HARK_CONF = $override
$out = Invoke-Hark @('test')
Assert-Contains 'per-role override wins' 'C:\mine.wav' $out

# --- the config file must never be executed -------------------------------
$canary = Join-Path $Tmp 'canary.txt'
$evil = Join-Path $Tmp 'evil.conf'
"HARK_PRESET=default`nHARK_VOLUME=`$(New-Item -ItemType File -Path '$canary')`n" |
    Set-Content -LiteralPath $evil
$env:HARK_CONF = $evil
Invoke-Hark @('test') | Out-Null
if (Test-Path -LiteralPath $canary) {
    Test-No 'config file is not executed' 'no canary file' 'canary was created'
} else {
    Test-Ok 'config file is not executed'
}

# --- never breaks the session ---------------------------------------------
$env:HARK_CONF = Join-Path $Tmp 'absent.conf'
Invoke-Hark @('done') | Out-Null
Assert-Equals 'exit 0 on a known role' 0 $LASTEXITCODE
Invoke-Hark @('not_a_role') | Out-Null
Assert-Equals 'exit 0 on an unknown role' 0 $LASTEXITCODE
Invoke-Hark @() | Out-Null
Assert-Equals 'exit 0 with no argument' 0 $LASTEXITCODE

# --- Codex payloads map to roles without a JSON parser --------------------
$out = Invoke-Hark @('codex', '{"type":"agent-turn-complete","last-assistant-message":"ok"}')
Assert-Contains 'codex turn-complete plays done' 'done.wav' $out

$out = Invoke-Hark @('codex', '{"type":"approval-requested"}')
Assert-Contains 'codex approval-requested plays attention' 'attention.wav' $out

$out = Invoke-Hark @('codex', '{"type":"something-else"}')
Assert-Equals 'unknown codex event is silent' '' $out

$out = Invoke-Hark @('codex', 'not json at all')
Assert-Equals 'malformed codex payload is silent' '' $out

# --- bundled sounds -------------------------------------------------------
$missing = @()
foreach ($r in @('done', 'attention', 'error', 'subagent', 'bye')) {
    foreach ($n in @("$r.wav", "subtle-$r.wav")) {
        if (-not (Test-Path -LiteralPath (Join-Path $Root "sounds/$n"))) { $missing += $n }
    }
}
Assert-Equals 'all bundled sounds are present' '' ($missing -join ' ')

Remove-Item -Recurse -Force $Tmp
Write-Host ''
Write-Host "$script:Pass passed, $script:Fail failed"
if ($script:Fail -gt 0) { exit 1 }
