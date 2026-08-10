#!/usr/bin/env pwsh
<#
.SYNOPSIS
    claude-chime - play a sound when Claude Code finishes or needs you.

.DESCRIPTION
    The Windows counterpart of scripts/chime.sh. Same config file, same
    presets, same roles, so a user moving between machines gets the same
    behaviour from the same ~/.claude/chime.conf.

    Media.SoundPlayer plays WAV only, which is why every bundled sound is WAV.
    It has no volume control, so CHIME_VOLUME is accepted and ignored here.

    Exits 0 in every path. A notifier must never be able to break a session.

.PARAMETER Role
    done | attention | error | subagent | bye | test
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Role = ''
)

$ErrorActionPreference = 'SilentlyContinue'

$ChimeRoot = if ($env:CHIME_ROOT) {
    $env:CHIME_ROOT
} else {
    Split-Path -Parent (Split-Path -Parent $PSCommandPath)
}
$SoundsDir = Join-Path $ChimeRoot 'sounds'
$AllRoles = @('done', 'attention', 'error', 'subagent', 'bye')

# --------------------------------------------------------------------------
# config: built-in defaults < ~/.claude/chime.conf < environment
# --------------------------------------------------------------------------

$FileConfig = @{}
# if/else rather than the ternary operator: the hook invokes `powershell`,
# which on Windows is PowerShell 5.1, and `? :` only exists from 7 onwards.
if ($HOME) { $HomeDir = $HOME } else { $HomeDir = $env:USERPROFILE }
if ($env:CHIME_CONF) {
    $ConfPath = $env:CHIME_CONF
} else {
    $ConfPath = Join-Path $HomeDir '.claude/chime.conf'
}

if (Test-Path -LiteralPath $ConfPath) {
    foreach ($line in (Get-Content -LiteralPath $ConfPath)) {
        $split = $line.IndexOf('=')
        if ($split -lt 1) { continue }  # comments, blanks, junk
        $key = $line.Substring(0, $split).Trim()
        $value = $line.Substring($split + 1).Trim().Trim('"')
        # Allowlist, never Invoke-Expression: a config file must not run code.
        if ($key -match '^CHIME_(PRESET|VOLUME|PLAYER|SOUND_(DONE|ATTENTION|ERROR|SUBAGENT|BYE))$') {
            $FileConfig[$key] = $value
        }
    }
}

function Get-ChimeSetting {
    param([string]$Name)
    $fromEnv = [Environment]::GetEnvironmentVariable($Name)
    if ($fromEnv) { return $fromEnv }
    if ($FileConfig.ContainsKey($Name)) { return $FileConfig[$Name] }
    return ''
}

# --------------------------------------------------------------------------
# which file does (preset, role) mean?  '' means stay silent.
# --------------------------------------------------------------------------

function Resolve-ChimeSound {
    param([string]$ForRole)

    $override = Get-ChimeSetting "CHIME_SOUND_$($ForRole.ToUpper())"
    if ($override) { return $override }

    $preset = Get-ChimeSetting 'CHIME_PRESET'
    if (-not $preset) { $preset = 'default' }

    switch ($preset) {
        'off' { return '' }
        'minimal' {
            if ($ForRole -eq 'done' -or $ForRole -eq 'attention') {
                return (Join-Path $SoundsDir "$ForRole.wav")
            }
            return ''
        }
        'subtle' { return (Join-Path $SoundsDir "subtle-$ForRole.wav") }
        'macos' {
            # Paths that only exist on macOS. Invoke-ChimePlayer skips anything
            # missing, so this preset is simply silent here.
            switch ($ForRole) {
                'done' { return '/System/Library/Sounds/Glass.aiff' }
                'attention' { return '/System/Library/Sounds/Funk.aiff' }
                'error' { return '/System/Library/Sounds/Basso.aiff' }
                'subagent' { return '/System/Library/Sounds/Tink.aiff' }
                default { return '' }
            }
        }
        default { return (Join-Path $SoundsDir "$ForRole.wav") }
    }
}

# --------------------------------------------------------------------------

function Invoke-ChimePlayer {
    param([string]$File)

    if (-not $File) { return }
    if (-not (Test-Path -LiteralPath $File)) { return }

    # An explicit player is how the test suite observes playback without noise.
    $player = Get-ChimeSetting 'CHIME_PLAYER'
    if ($player) {
        & $player $File
        return
    }

    (New-Object Media.SoundPlayer $File).PlaySync()
}

# --------------------------------------------------------------------------

switch ($Role) {
    '' {
        Write-Host 'usage: chime.ps1 <done|attention|error|subagent|bye|test>'
    }
    'test' {
        foreach ($r in $AllRoles) {
            $file = Resolve-ChimeSound $r
            if ($file) {
                Write-Output "$r -> $file"
                Invoke-ChimePlayer $file
            }
        }
    }
    default {
        Invoke-ChimePlayer (Resolve-ChimeSound $Role)
    }
}

exit 0
