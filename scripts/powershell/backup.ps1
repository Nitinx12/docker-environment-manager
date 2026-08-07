<#
.SYNOPSIS
    backup.ps1 - Back up Docker named volumes to compressed tarballs.

.DESCRIPTION
    Usage:
      .\backup.ps1 [-p|--project <name>] [-v|--volume <name>]... [-o|--output <dir>] [-h|--help]

    With no -v/--volume flags, backs up every volume Docker Compose tagged
    with this project's label (com.docker.compose.project=<name>). Each
    volume is streamed through a throwaway alpine container so no host
    mount permissions are required.
    Reads defaults from <repo>/.env, overridable by CLI flags.
    Mirrors scripts/bash/backup.sh.
#>

$ScriptDir = $PSScriptRoot
. (Join-Path $ScriptDir 'lib/common.ps1')

function Show-Usage {
    @"
Usage: backup.ps1 [OPTIONS]

Back up Docker named volumes to timestamped .tar.gz archives.

Options:
  -p, --project <name>  Compose project name used to auto-discover volumes (default: from .env or docker-env-manager)
  -v, --volume <name>   Back up a specific volume (repeatable). Overrides project auto-discovery.
  -o, --output <dir>    Directory to write backups to (default: ./backups)
  -h, --help            Show this help message
"@ | Write-Host
}

# ---- Load config, then apply CLI overrides ------------------------------
load_env

$ProjectName = 'docker-env-manager'
if ($global:PROJECT_NAME) { $ProjectName = $global:PROJECT_NAME }

$OutputDir = 'backups'
if ($global:BACKUP_DIR) { $OutputDir = $global:BACKUP_DIR }

$Volumes = @()

$i = 0
while ($i -lt $args.Count) {
    $arg = $args[$i]
    if ($arg -eq '-p' -or $arg -eq '--project') {
        if ($i + 1 -ge $args.Count) { log_error "Missing value for $arg"; exit 1 }
        $ProjectName = $args[$i + 1]; $i += 2
    }
    elseif ($arg -eq '-v' -or $arg -eq '--volume') {
        if ($i + 1 -ge $args.Count) { log_error "Missing value for $arg"; exit 1 }
        $Volumes += $args[$i + 1]; $i += 2
    }
    elseif ($arg -eq '-o' -or $arg -eq '--output') {
        if ($i + 1 -ge $args.Count) { log_error "Missing value for $arg"; exit 1 }
        $OutputDir = $args[$i + 1]; $i += 2
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

$OutputDir = Resolve-UnderRepoRoot $OutputDir
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

# ---- Discover volumes if none were given explicitly -----------------------
if ($Volumes.Count -eq 0) {
    log_info "Discovering volumes for project '$ProjectName'"
    $discovered = @(& docker volume ls -q -f "label=com.docker.compose.project=$ProjectName" | Where-Object { $_ })
    foreach ($vol in $discovered) {
        $Volumes += $vol
    }
}

if ($Volumes.Count -eq 0) {
    log_error "No volumes found for project '$ProjectName'. Use -v to specify one explicitly."
    exit 1
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$failures = 0

foreach ($volume in $Volumes) {
    & docker volume inspect $volume *> $null
    if ($LASTEXITCODE -ne 0) {
        log_error "Volume not found: $volume"
        $failures += 1
        continue
    }

    $archiveName = "$volume-$timestamp.tar.gz"
    $destPath = Join-Path $OutputDir $archiveName
    log_info "Backing up volume '$volume' -> $destPath"

    # Write the archive inside a throwaway container first, then use
    # 'docker cp' to pull it out. Unlike a host bind mount, docker cp is
    # streamed over the Docker API, so it works even when the Docker
    # daemon doesn't share a filesystem with this shell (e.g. Docker
    # Outside of Docker in a devcontainer/Codespace).
    $containerName = ("backup-$volume-$timestamp" -replace '[^a-zA-Z0-9_.-]', '-')

    & docker create --name $containerName -v "${volume}:/volume:ro" alpine:3.20 `
        tar czf /tmp/archive.tar.gz -C /volume . | Out-Null
    if ($LASTEXITCODE -ne 0) {
        log_error "Failed to create backup container for '$volume'"
        $failures += 1
        continue
    }

    & docker start -a $containerName | Out-Null
    $tarOk = ($LASTEXITCODE -eq 0)

    $copyOk = $false
    if ($tarOk) {
        & docker cp "${containerName}:/tmp/archive.tar.gz" $destPath
        $copyOk = ($LASTEXITCODE -eq 0)
    }

    & docker rm -f $containerName *> $null

    if ($tarOk -and $copyOk) {
        log_success "Backed up '$volume'"
    }
    else {
        log_error "Failed to back up '$volume'"
        $failures += 1
    }
}

if ($failures -gt 0) {
    log_error "$failures volume(s) failed to back up."
    exit 1
}

log_success "All volumes backed up to $OutputDir"