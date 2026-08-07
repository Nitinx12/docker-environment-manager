<#
.SYNOPSIS
    logs.ps1 - View or tail logs for the Docker Compose stack.

.DESCRIPTION
    Usage:
      .\logs.ps1 [-f|--file <compose-file>] [-p|--project <name>] [-s|--service <name>] [-n|--tail <lines>] [--follow] [-h|--help] [SERVICE]

    Reads defaults from <repo>/.env, overridable by CLI flags.
    Mirrors scripts/bash/logs.sh.
#>

$ScriptDir = $PSScriptRoot
. (Join-Path $ScriptDir 'lib/common.ps1')

function Show-Usage {
    @"
Usage: logs.ps1 [OPTIONS] [SERVICE]

View logs for the Docker Compose stack.

Options:
  -f, --file <path>     Path to docker-compose file (default: from .env or docker/docker-compose.yml)
  -p, --project <name>  Compose project name (default: from .env or docker-env-manager)
  -s, --service <name>  Only show logs for this service (can also be given positionally)
      --follow          Stream logs continuously (like tail -f)
  -n, --tail <lines>    Number of lines to show from the end (default: 100)
  -h, --help            Show this help message
"@ | Write-Host
}

# ---- Load config, then apply CLI overrides ------------------------------
load_env

$ComposeFile = 'docker/docker-compose.yml'
if ($global:COMPOSE_FILE) { $ComposeFile = $global:COMPOSE_FILE }

$ProjectName = 'docker-env-manager'
if ($global:PROJECT_NAME) { $ProjectName = $global:PROJECT_NAME }

$Service = ''
$TailLines = '100'
$FollowFlag = $false

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
    elseif ($arg -eq '-s' -or $arg -eq '--service') {
        if ($i + 1 -ge $args.Count) { log_error "Missing value for $arg"; exit 1 }
        $Service = $args[$i + 1]; $i += 2
    }
    elseif ($arg -eq '--follow') {
        $FollowFlag = $true; $i += 1
    }
    elseif ($arg -eq '-n' -or $arg -eq '--tail') {
        if ($i + 1 -ge $args.Count) { log_error "Missing value for $arg"; exit 1 }
        $TailLines = $args[$i + 1]; $i += 2
    }
    elseif ($arg -eq '-h' -or $arg -eq '--help') {
        Show-Usage; exit 0
    }
    else {
        # Allow a bare positional service name too: .\logs.ps1 airflow-scheduler
        $Service = $arg; $i += 1
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

$serviceSuffix = ''
if ($Service) { $serviceSuffix = " (service: $Service)" }
log_info "Showing logs for '$ProjectName'$serviceSuffix"

$composeArgs = @('compose', '-f', $ComposeFile, '-p', $ProjectName, 'logs', '--tail', $TailLines)
if ($FollowFlag) { $composeArgs += '--follow' }
if ($Service) { $composeArgs += $Service }

& docker @composeArgs
exit $LASTEXITCODE