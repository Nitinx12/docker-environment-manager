<#
.SYNOPSIS
    cleanup.ps1 - Clean up Docker resources for this project (and optionally
    the host).

.DESCRIPTION
    Usage:
      .\cleanup.ps1 [-f|--file <compose-file>] [-p|--project <name>] [-a|--all] [-v|--volumes] [-n|--dry-run] [-h|--help]

    By default, only removes this project's stopped/orphaned containers and
    dangling images. Use -a/--all for a broader host-wide
    'docker system prune'. Reads defaults from <repo>/.env, overridable by
    CLI flags. Mirrors scripts/bash/cleanup.sh.
#>

$ScriptDir = $PSScriptRoot
. (Join-Path $ScriptDir 'lib/common.ps1')

function Show-Usage {
    @"
Usage: cleanup.ps1 [OPTIONS]

Clean up Docker resources.

Options:
  -f, --file <path>     Path to docker-compose file (default: from .env or docker/docker-compose.yml)
  -p, --project <name>  Compose project name (default: from .env or docker-env-manager)
  -a, --all             Also run a host-wide 'docker system prune' (images, build cache, networks)
  -v, --volumes         Also remove this project's named volumes (DESTRUCTIVE)
  -n, --dry-run         Show what would be removed without removing anything
  -h, --help            Show this help message
"@ | Write-Host
}

# ---- Load config, then apply CLI overrides ------------------------------
load_env

$ComposeFile = 'docker/docker-compose.yml'
if ($global:COMPOSE_FILE) { $ComposeFile = $global:COMPOSE_FILE }

$ProjectName = 'docker-env-manager'
if ($global:PROJECT_NAME) { $ProjectName = $global:PROJECT_NAME }

$AllFlag = $false
$VolumesFlag = $false
$DryRun = $false

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
    elseif ($arg -eq '-a' -or $arg -eq '--all') {
        $AllFlag = $true; $i += 1
    }
    elseif ($arg -eq '-v' -or $arg -eq '--volumes') {
        $VolumesFlag = $true; $i += 1
    }
    elseif ($arg -eq '-n' -or $arg -eq '--dry-run') {
        $DryRun = $true; $i += 1
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

if ($DryRun) {
    log_warn "Dry run: no resources will be removed"
}

# ---- Project-scoped cleanup ------------------------------------------------
if (Test-Path -LiteralPath $ComposeFile -PathType Leaf) {
    log_info "Removing stopped/orphaned containers for project '$ProjectName'"
    if ($DryRun) {
        & docker compose -f $ComposeFile -p $ProjectName ps -a
    }
    else {
        $downArgs = @('compose', '-f', $ComposeFile, '-p', $ProjectName, 'down', '--remove-orphans')
        if ($VolumesFlag) {
            log_warn "Named volumes for '$ProjectName' will be removed"
            $downArgs += '--volumes'
        }
        & docker @downArgs
    }
}
else {
    log_warn "Compose file not found: $ComposeFile - skipping project-scoped cleanup"
}

log_info "Removing dangling images"
$danglingIds = @(& docker images -f "dangling=true" -q | Where-Object { $_ })
if ($danglingIds.Count -gt 0) {
    if ($DryRun) {
        & docker images -f "dangling=true"
    }
    else {
        & docker rmi @danglingIds 2>$null
        if ($LASTEXITCODE -ne 0) {
            log_warn "Some dangling images could not be removed (still in use)"
        }
    }
}
else {
    log_info "No dangling images found"
}

# ---- Host-wide cleanup ------------------------------------------------
if ($AllFlag) {
    log_info "Running host-wide docker system prune"
    $pruneArgs = @('--force')
    if ($VolumesFlag) { $pruneArgs += '--volumes' }

    if ($DryRun) {
        log_info "(dry run) Would run: docker system prune $($pruneArgs -join ' ')"
        & docker system df
    }
    else {
        & docker system prune @pruneArgs
    }
}

log_success "Cleanup complete."