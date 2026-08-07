<#
.SYNOPSIS
    restart.ps1 - Restart the Docker Compose stack for this project.

.DESCRIPTION
    Usage:
      .\restart.ps1 [-f|--file <compose-file>] [-p|--project <name>] [-b|--build] [-h|--help]

    Equivalent to running stop.ps1 followed by start.ps1 with the same
    flags. Reads defaults from <repo>/.env, overridable by CLI flags.
    Mirrors scripts/bash/restart.sh.
#>

$ScriptDir = $PSScriptRoot
. (Join-Path $ScriptDir 'lib/common.ps1')

function Show-Usage {
    @"
Usage: restart.ps1 [OPTIONS]

Restart the Docker Compose stack (stop, then start).

Options:
  -f, --file <path>     Path to docker-compose file (default: from .env or docker/docker-compose.yml)
  -p, --project <name>  Compose project name (default: from .env or docker-env-manager)
  -b, --build           Rebuild images before starting back up
  -h, --help            Show this help message
"@ | Write-Host
}

# ---- Load config, then apply CLI overrides ------------------------------
load_env

$ComposeFile = 'docker/docker-compose.yml'
if ($global:COMPOSE_FILE) { $ComposeFile = $global:COMPOSE_FILE }

$ProjectName = 'docker-env-manager'
if ($global:PROJECT_NAME) { $ProjectName = $global:PROJECT_NAME }

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

# ---- Preflight checks ----------------------------------------------------
require_docker
require_command 'docker'

log_info "Restarting stack '$ProjectName'"

# ---- Stop, then start -----------------------------------------------------
# Each child script resolves the compose file relative to the repo root
# itself, so pass it through as-received rather than resolving it twice.
$StopScript = Join-Path $ScriptDir 'stop.ps1'
$StartScript = Join-Path $ScriptDir 'start.ps1'

& $StopScript -f $ComposeFile -p $ProjectName
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$startArgs = @('-f', $ComposeFile, '-p', $ProjectName)
if ($BuildFlag) { $startArgs += '-b' }

& $StartScript @startArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

log_success "Stack '$ProjectName' restarted."