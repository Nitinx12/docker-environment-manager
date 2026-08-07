<#
.SYNOPSIS
    health.ps1 - Report or wait for the health status of the Docker Compose
    stack.

.DESCRIPTION
    Usage:
      .\health.ps1 [-f|--file <compose-file>] [-p|--project <name>] [-w|--wait] [-t|--timeout <seconds>] [-h|--help]

    Exits 0 if every container with a healthcheck is healthy (or none
    define one). Exits 1 if any container is unhealthy, or if -w/--wait
    times out while containers are still starting. Intended as a
    standalone CI step after start.ps1, or for manual spot-checks.
    Reads defaults from <repo>/.env, overridable by CLI flags.
    Mirrors scripts/bash/health.sh.
#>

$ScriptDir = $PSScriptRoot
. (Join-Path $ScriptDir 'lib/common.ps1')

function Show-Usage {
    @"
Usage: health.ps1 [OPTIONS]

Check (or wait for) the health status of the Docker Compose stack.

Options:
  -f, --file <path>     Path to docker-compose file (default: from .env or docker/docker-compose.yml)
  -p, --project <name>  Compose project name (default: from .env or docker-env-manager)
  -w, --wait            Wait out containers still reporting "starting" instead of failing immediately
  -t, --timeout <secs>  Max seconds to wait when -w/--wait is set (default: 60)
  -h, --help            Show this help message
"@ | Write-Host
}

# ---- Load config, then apply CLI overrides ------------------------------
load_env

$ComposeFile = 'docker/docker-compose.yml'
if ($global:COMPOSE_FILE) { $ComposeFile = $global:COMPOSE_FILE }

$ProjectName = 'docker-env-manager'
if ($global:PROJECT_NAME) { $ProjectName = $global:PROJECT_NAME }

$WaitFlag = $false
$Timeout = 60
if ($global:HEALTH_TIMEOUT) { $Timeout = [int]$global:HEALTH_TIMEOUT }

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
    elseif ($arg -eq '-w' -or $arg -eq '--wait') {
        $WaitFlag = $true; $i += 1
    }
    elseif ($arg -eq '-t' -or $arg -eq '--timeout') {
        if ($i + 1 -ge $args.Count) { log_error "Missing value for $arg"; exit 1 }
        $Timeout = [int]$args[$i + 1]; $i += 2
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

# Returns @(unhealthyCount, startingCount). Containers with no healthcheck
# defined report no "Health" field at all and are ignored.
function Test-ComposeHealthOnce {
    $psOutput = & docker compose -f $ComposeFile -p $ProjectName ps --format json 2>$null
    $psText = ($psOutput -join "`n")
    $unhealthy = ([regex]::Matches($psText, '"Health":"unhealthy"')).Count
    $starting = ([regex]::Matches($psText, '"Health":"starting"')).Count
    return @($unhealthy, $starting)
}

log_info "Checking health for '$ProjectName'"

$elapsed = 0
$interval = 3
while ($true) {
    $result = Test-ComposeHealthOnce
    $unhealthy = $result[0]
    $starting = $result[1]

    if ($unhealthy -gt 0) {
        log_error "$unhealthy container(s) unhealthy."
        & docker compose -f $ComposeFile -p $ProjectName ps
        exit 1
    }

    if ($starting -eq 0) {
        log_success "All containers are up and healthy."
        & docker compose -f $ComposeFile -p $ProjectName ps
        exit 0
    }

    if (-not $WaitFlag) {
        log_warn "$starting container(s) still starting (use -w/--wait to wait it out)."
        & docker compose -f $ComposeFile -p $ProjectName ps
        exit 1
    }

    if ($elapsed -ge $Timeout) {
        log_error "Timed out after ${Timeout}s waiting for healthy status."
        & docker compose -f $ComposeFile -p $ProjectName ps
        exit 1
    }

    Start-Sleep -Seconds $interval
    $elapsed += $interval
}