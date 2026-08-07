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

# ---- Load config ---------------------------------------------------------

load_env

$ComposeFile = 'docker/docker-compose.yml'
if ($global:COMPOSE_FILE) {
    $ComposeFile = $global:COMPOSE_FILE
}

$ProjectName = 'docker-env-manager'
if ($global:PROJECT_NAME) {
    $ProjectName = $global:PROJECT_NAME
}

$Service = ''
$TailLines = '100'
$FollowFlag = $false

# ---- Parse arguments -----------------------------------------------------

$i = 0
while ($i -lt $args.Count) {
    $arg = $args[$i]

    switch ($arg) {
        '-f' {
            if ($i + 1 -ge $args.Count) {
                log_error "Missing value for $arg"
                exit 1
            }
            $ComposeFile = $args[$i + 1]
            $i += 2
            continue
        }

        '--file' {
            if ($i + 1 -ge $args.Count) {
                log_error "Missing value for $arg"
                exit 1
            }
            $ComposeFile = $args[$i + 1]
            $i += 2
            continue
        }

        '-p' {
            if ($i + 1 -ge $args.Count) {
                log_error "Missing value for $arg"
                exit 1
            }
            $ProjectName = $args[$i + 1]
            $i += 2
            continue
        }

        '--project' {
            if ($i + 1 -ge $args.Count) {
                log_error "Missing value for $arg"
                exit 1
            }
            $ProjectName = $args[$i + 1]
            $i += 2
            continue
        }

        '-s' {
            if ($i + 1 -ge $args.Count) {
                log_error "Missing value for $arg"
                exit 1
            }
            $Service = $args[$i + 1]
            $i += 2
            continue
        }

        '--service' {
            if ($i + 1 -ge $args.Count) {
                log_error "Missing value for $arg"
                exit 1
            }
            $Service = $args[$i + 1]
            $i += 2
            continue
        }

        '--follow' {
            $FollowFlag = $true
            $i++
            continue
        }

        '-n' {
            if ($i + 1 -ge $args.Count) {
                log_error "Missing value for $arg"
                exit 1
            }
            $TailLines = $args[$i + 1]
            $i += 2
            continue
        }

        '--tail' {
            if ($i + 1 -ge $args.Count) {
                log_error "Missing value for $arg"
                exit 1
            }
            $TailLines = $args[$i + 1]
            $i += 2
            continue
        }

        '-h' {
            Show-Usage
            exit 0
        }

        '--help' {
            Show-Usage
            exit 0
        }

        default {
            # Treat a bare argument as the service name.
            $Service = $arg
            $i++
        }
    }
}

# ---- Resolve compose file ------------------------------------------------

$ComposeFile = Resolve-UnderRepoRoot $ComposeFile

# ---- Validate compose file BEFORE Docker checks --------------------------

if (-not (Test-Path -LiteralPath $ComposeFile -PathType Leaf)) {
    log_error "Compose file not found: $ComposeFile"
    exit 1
}

# ---- Preflight checks ----------------------------------------------------

require_docker
require_command 'docker'

$serviceSuffix = ''
if ($Service) {
    $serviceSuffix = " (service: $Service)"
}

log_info "Showing logs for '$ProjectName'$serviceSuffix"

$composeArgs = @(
    'compose'
    '-f'
    $ComposeFile
    '-p'
    $ProjectName
    'logs'
    '--tail'
    $TailLines
)

if ($FollowFlag) {
    $composeArgs += '--follow'
}

if ($Service) {
    $composeArgs += $Service
}

& docker @composeArgs
exit $LASTEXITCODE