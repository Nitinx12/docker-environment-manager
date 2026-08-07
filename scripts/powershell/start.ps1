<#
.SYNOPSIS
    start.ps1 - Start the Docker Compose stack for this project.

.DESCRIPTION
    Usage:
      .\start.ps1 [-f|--file <compose-file>] [-p|--project <name>] [-b|--build] [-h|--help]

    Reads defaults from <repo>/.env (see .env.example), which can be
    overridden by flags on the command line. Mirrors scripts/bash/start.sh.
#>

$ScriptDir = $PSScriptRoot
. (Join-Path $ScriptDir 'lib/common.ps1')

function Show-Usage {
    @"
Usage: start.ps1 [OPTIONS]

Start the Docker Compose stack.

Options:
  -f, --file <path>     Path to docker-compose file (default: from .env or docker/docker-compose.yml)
  -p, --project <name>  Compose project name (default: from .env or docker-env-manager)
  -b, --build           Rebuild images before starting
  -h, --help            Show this help message
"@ | Write-Host
}

# ---- Load config, then apply CLI overrides ------------------------------
load_env

$ComposeFile = 'docker/docker-compose.yml'
if ($global:COMPOSE_FILE) { $ComposeFile = $global:COMPOSE_FILE }

$ProjectName = 'docker-env-manager'
if ($global:PROJECT_NAME) { $ProjectName = $global:PROJECT_NAME }

$HealthTimeout = 60
if ($global:HEALTH_TIMEOUT) { $HealthTimeout = [int]$global:HEALTH_TIMEOUT }

$BuildFlag = $false

$i = 0
while ($i -lt $args.Count) {
    $arg = $args[$i]
    if ($arg -eq '-f' -or $arg -eq '--file') {
        if ($i + 1 -ge $args.Count) { log_error "Missing value for $arg"; exit 1 }
        $ComposeFile = $args[$i + 1]; $i += 2
    }
    elseif ($arg -eq '-p' -or $arg -eq '--project') {
        if ($i + 1 -ge $args.Count) { log_error "Missing value for $arg"; exit 1 }
        $ProjectName = $args[$i + 1]; $i += 2
    }
    elseif ($arg -eq '-b' -or $arg -eq '--build') {
        $BuildFlag = $true; $i += 1
    }
    elseif ($arg -eq '-h' -or $arg -eq '--help') {
        Show-Usage; exit 0
    }
    else {
        log_error "Unknown option: $arg"
        Show-Usage
        exit 1
    }
}

# Resolve compose file relative to repo root if a relative path was given
$ComposeFile = Resolve-UnderRepoRoot $ComposeFile

# ---- Preflight checks ----------------------------------------------------
require_docker
require_command 'docker'

if (-not (Test-Path -LiteralPath $ComposeFile -PathType Leaf)) {
    log_error "Compose file not found: $ComposeFile"
    exit 1
}

log_info "Starting stack '$ProjectName' using $ComposeFile"

# ---- Start containers ----------------------------------------------------
$composeArgs = @('compose', '-f', $ComposeFile, '-p', $ProjectName, 'up', '-d')
if ($BuildFlag) { $composeArgs += '--build' }

& docker @composeArgs
if ($LASTEXITCODE -ne 0) {
    log_error "docker compose up failed"
    exit 1
}

log_success "Containers started for project '$ProjectName'"

# ---- Wait for healthy status ---------------------------------------------
log_info "Waiting up to ${HealthTimeout}s for containers to report healthy..."

$elapsed = 0
$interval = 3
while ($elapsed -lt $HealthTimeout) {
    $psOutput = & docker compose -f $ComposeFile -p $ProjectName ps --format json 2>$null
    $psText = ($psOutput -join "`n")

    $unhealthy = ([regex]::Matches($psText, '"Health":"unhealthy"')).Count
    $starting = ([regex]::Matches($psText, '"Health":"starting"')).Count

    if ($unhealthy -gt 0) {
        log_error "One or more containers are unhealthy. Run './logs.ps1' for details."
        exit 1
    }

    if ($starting -eq 0) {
        log_success "All containers are up and healthy."
        & docker compose -f $ComposeFile -p $ProjectName ps
        exit 0
    }

    Start-Sleep -Seconds $interval
    $elapsed += $interval
}

log_warn "Timed out after ${HealthTimeout}s waiting for healthy status. Current state:"
& docker compose -f $ComposeFile -p $ProjectName ps
exit 0