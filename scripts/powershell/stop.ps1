<#
.SYNOPSIS
    stop.ps1 - Stop the Docker Compose stack for this project.

.DESCRIPTION
    Usage:
      .\stop.ps1 [-f|--file <compose-file>] [-p|--project <name>] [-v|--volumes] [-h|--help]

    Reads defaults from <repo>/.env (see .env.example), which can be
    overridden by flags on the command line. Mirrors scripts/bash/stop.sh.
#>

$ScriptDir = $PSScriptRoot
. (Join-Path $ScriptDir 'lib/common.ps1')

function Show-Usage {
    @"
Usage: stop.ps1 [OPTIONS]

Stop the Docker Compose stack.

Options:
  -f, --file <path>     Path to docker-compose file (default: from .env or docker/docker-compose.yml)
  -p, --project <name>  Compose project name (default: from .env or docker-env-manager)
  -v, --volumes         Also remove named volumes declared in the compose file
  -h, --help            Show this help message
"@ | Write-Host
}

# ---- Load config, then apply CLI overrides ------------------------------
load_env

$ComposeFile = 'docker/docker-compose.yml'
if ($global:COMPOSE_FILE) { $ComposeFile = $global:COMPOSE_FILE }

$ProjectName = 'docker-env-manager'
if ($global:PROJECT_NAME) { $ProjectName = $global:PROJECT_NAME }

$VolumesFlag = $false

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
    elseif ($arg -eq '-v' -or $arg -eq '--volumes') {
        $VolumesFlag = $true; $i += 1
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

log_info "Stopping stack '$ProjectName' using $ComposeFile"

if ($VolumesFlag) {
    log_warn "Named volumes for '$ProjectName' will be removed"
}

# ---- Stop containers ------------------------------------------------------
$composeArgs = @('compose', '-f', $ComposeFile, '-p', $ProjectName, 'down')
if ($VolumesFlag) { $composeArgs += '--volumes' }

& docker @composeArgs
if ($LASTEXITCODE -ne 0) {
    log_error "docker compose down failed"
    exit 1
}

log_success "Stack '$ProjectName' stopped."