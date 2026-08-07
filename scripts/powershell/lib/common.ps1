<#
.SYNOPSIS
    common.ps1 - Shared helper functions for the Docker Environment Manager
    PowerShell scripts.

.DESCRIPTION
    Mirrors scripts/bash/lib/common.sh so the Bash and PowerShell toolkits
    behave identically. Dot-source this file from every script:

        . (Join-Path $PSScriptRoot 'lib/common.ps1')

    Provides:
      - log_info / log_warn / log_error / log_success   (console logging)
      - load_env                                          (reads <repo>/.env)
      - require_command / require_docker                  (preflight checks)
      - Resolve-UnderRepoRoot                              (path helper)
      - $Script:RepoRoot                                   (repo root path)

    This file lives at <repo>/scripts/powershell/lib/common.ps1, so the repo
    root is three levels up (lib -> powershell -> scripts -> repo).
#>

$Script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path

# ---- Logging ----------------------------------------------------------

function log_info {
    param([Parameter(Mandatory, Position = 0)][string]$Message)
    Write-Host "[INFO]  $Message" -ForegroundColor Cyan
}

function log_warn {
    param([Parameter(Mandatory, Position = 0)][string]$Message)
    Write-Host "[WARN]  $Message" -ForegroundColor Yellow
}

function log_error {
    param([Parameter(Mandatory, Position = 0)][string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function log_success {
    param([Parameter(Mandatory, Position = 0)][string]$Message)
    Write-Host "[OK]    $Message" -ForegroundColor Green
}

# ---- .env loader -------------------------------------------------------
#
# Reads KEY=VALUE pairs from <repo>/.env into Global-scope variables of the
# same name (and into $env:), so scripts can do:
#
#   $Project = 'docker-env-manager'
#   if ($global:PROJECT_NAME) { $Project = $global:PROJECT_NAME }
#
# which mirrors Bash's `${PROJECT_NAME:-docker-env-manager}` pattern.
# Lines starting with '#' and blank lines are ignored. Values may optionally
# be wrapped in single or double quotes, which are stripped.

function load_env {
    $envFile = Join-Path $Script:RepoRoot '.env'
    if (-not (Test-Path -LiteralPath $envFile -PathType Leaf)) {
        return
    }

    foreach ($rawLine in Get-Content -LiteralPath $envFile) {
        $line = $rawLine.Trim()
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
            continue
        }
        if ($line -notmatch '^[A-Za-z_][A-Za-z0-9_]*=') {
            continue
        }

        $splitIndex = $line.IndexOf('=')
        $key = $line.Substring(0, $splitIndex).Trim()
        $value = $line.Substring($splitIndex + 1).Trim()

        if ($value.Length -ge 2) {
            $first = $value[0]
            $last = $value[$value.Length - 1]
            if (($first -eq '"' -and $last -eq '"') -or ($first -eq "'" -and $last -eq "'")) {
                $value = $value.Substring(1, $value.Length - 2)
            }
        }

        Set-Variable -Name $key -Value $value -Scope Global
        Set-Item -Path "Env:$key" -Value $value
    }
}

# ---- Preflight checks ---------------------------------------------------

function require_command {
    param([Parameter(Mandatory, Position = 0)][string]$Name)
    if (-not (Get-Command -Name $Name -ErrorAction SilentlyContinue)) {
        log_error "Required command not found on PATH: $Name"
        exit 1
    }
}

function require_docker {
    require_command 'docker'
    docker info *> $null
    if ($LASTEXITCODE -ne 0) {
        log_error "Docker does not appear to be running. Start Docker Desktop / the Docker daemon and try again."
        exit 1
    }
}

# ---- Path helper ---------------------------------------------------------
#
# Resolves a possibly-relative path against the repo root, matching each
# Bash script's `[[ "$X" != /* ]] && X="${REPO_ROOT}/${X}"` pattern.
# Does not require the path to exist.

function Resolve-UnderRepoRoot {
    param([Parameter(Mandatory, Position = 0)][string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }
    return (Join-Path $Script:RepoRoot $Path)
}
