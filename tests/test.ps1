<#
.SYNOPSIS
    Self-check for chime.ps1. Mirrors the assertions in tests/test.sh.

.DESCRIPTION
    Run with:  powershell -NoProfile -File tests/test.ps1

    Like the sh suite, this observes `chime.ps1 test` output (which prints the
    role -> file table before playing) and uses CHIME_PLAYER to stand in for
    the audio device, so nothing is ever heard.
#>

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$Chime = Join-Path $Root 'scripts/chime.ps1'
$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("chime-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $Tmp -Force | Out-Null

# Never read the developer's real config, and never make a sound.
$env:CHIME_CONF = Join-Path $Tmp 'absent.conf'
$env:CHIME_PLAYER = 'Write-Output'

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

function Invoke-Chime {
    param([string[]]$ChimeArgs)
    (& powershell -NoProfile -File $Chime @ChimeArgs 2>&1 | Out-String).Trim()
}

Write-Host 'chime.ps1 self-check'

# --- presets --------------------------------------------------------------
$env:CHIME_PRESET = 'default'
$out = Invoke-Chime @('test')
Assert-Contains 'default/done maps to done.wav' 'done.wav' $out
Assert-Contains 'default/error maps to error.wav' 'error.wav' $out

$env:CHIME_PRESET = 'subtle'
$out = Invoke-Chime @('test')
Assert-Contains 'subtle/done maps to subtle-done.wav' 'subtle-done.wav' $out

$env:CHIME_PRESET = 'minimal'
$out = Invoke-Chime @('test')
Assert-Contains 'minimal keeps done' 'done -> ' $out
Assert-Missing 'minimal silences error' 'error -> ' $out

$env:CHIME_PRESET = 'off'
$out = Invoke-Chime @('test')
Assert-Equals 'off resolves nothing at all' '' $out

$env:CHIME_PRESET = 'macos'
$out = Invoke-Chime @('test')
Assert-Contains 'macos/done is Glass' 'Glass.aiff' $out
Assert-Missing 'macos has no bye sound' 'bye -> ' $out

$env:CHIME_PRESET = 'nonsense'
$out = Invoke-Chime @('test')
Assert-Contains 'unknown preset behaves as default' 'done.wav' $out

# --- config file ----------------------------------------------------------
Remove-Item Env:\CHIME_PRESET
$basic = Join-Path $Tmp 'basic.conf'
"# a comment`nCHIME_PRESET=subtle`n" | Set-Content -LiteralPath $basic
$env:CHIME_CONF = $basic
$out = Invoke-Chime @('test')
Assert-Contains 'config file selects the preset' 'subtle-done.wav' $out

$env:CHIME_PRESET = 'macos'
$out = Invoke-Chime @('test')
Assert-Contains 'environment beats config file' 'Glass.aiff' $out
Remove-Item Env:\CHIME_PRESET

$override = Join-Path $Tmp 'override.conf'
"CHIME_PRESET=default`nCHIME_SOUND_DONE=C:\mine.wav`n" | Set-Content -LiteralPath $override
$env:CHIME_CONF = $override
$out = Invoke-Chime @('test')
Assert-Contains 'per-role override wins' 'C:\mine.wav' $out

# --- the config file must never be executed -------------------------------
$canary = Join-Path $Tmp 'canary.txt'
$evil = Join-Path $Tmp 'evil.conf'
"CHIME_PRESET=default`nCHIME_VOLUME=`$(New-Item -ItemType File -Path '$canary')`n" |
    Set-Content -LiteralPath $evil
$env:CHIME_CONF = $evil
Invoke-Chime @('test') | Out-Null
if (Test-Path -LiteralPath $canary) {
    Test-No 'config file is not executed' 'no canary file' 'canary was created'
} else {
    Test-Ok 'config file is not executed'
}

# --- never breaks the session ---------------------------------------------
$env:CHIME_CONF = Join-Path $Tmp 'absent.conf'
Invoke-Chime @('done') | Out-Null
Assert-Equals 'exit 0 on a known role' 0 $LASTEXITCODE
Invoke-Chime @('not_a_role') | Out-Null
Assert-Equals 'exit 0 on an unknown role' 0 $LASTEXITCODE
Invoke-Chime @() | Out-Null
Assert-Equals 'exit 0 with no argument' 0 $LASTEXITCODE

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
