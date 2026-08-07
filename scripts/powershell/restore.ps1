<#
.SYNOPSIS
    restore.ps1 - Restore a Docker named volume from a .tar.gz backup
    created by backup.ps1.

.DESCRIPTION
    Usage:
      .\restore.ps1 -v|--volume <name> -i|--input <file> [-c|--clean] [-y|--yes] [-h|--help]

    Reads defaults from <repo>/.env, overridable by CLI flags.
    Mirrors scripts/bash/restore.sh.
#>

$ScriptDir = $PSScriptRoot
. (Join-Path $ScriptDir 'lib/common.ps1')

function Show-Usage {
    @"
Usage: restore.ps1 -v <volume> -i <backup-file> [OPTIONS]

Restore a Docker named volume from a .tar.gz archive produced by backup.ps1.

Options:
  -v, --volume <name>   Target volume name (created automatically if it doesn't exist)
  -i, --input <file>    Path to the .tar.gz backup archive to restore
  -c, --clean           Remove the volume's existing contents before restoring
  -y, --yes             Skip the confirmation prompt
  -h, --help            Show this help message
"@ | Write-Host
}

# ---- Load config, then apply CLI overrides ------------------------------
load_env

$Volume = ''
$InputFile = ''
$CleanFlag = $false
$AssumeYes = $false

$i = 0
while ($i -lt $args.Count) {
    $arg = $args[$i]
    if ($arg -eq '-v' -or $arg -eq '--volume') {
        if ($i + 1 -ge $args.Count) { log_error "Missing value for $arg"; exit 1 }
        $Volume = $args[$i + 1]; $i += 2
    }
    elseif ($arg -eq '-i' -or $arg -eq '--input') {
        if ($i + 1 -ge $args.Count) { log_error "Missing value for $arg"; exit 1 }
        $InputFile = $args[$i + 1]; $i += 2
    }
    elseif ($arg -eq '-c' -or $arg -eq '--clean') {
        $CleanFlag = $true; $i += 1
    }
    elseif ($arg -eq '-y' -or $arg -eq '--yes') {
        $AssumeYes = $true; $i += 1
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

if (-not $Volume -or -not $InputFile) {
    log_error "Both -v/--volume and -i/--input are required"
    Show-Usage
    exit 1
}

# ---- Preflight checks ----------------------------------------------------
require_docker
require_command 'docker'

$InputFile = Resolve-UnderRepoRoot $InputFile

if (-not (Test-Path -LiteralPath $InputFile -PathType Leaf)) {
    log_error "Backup file not found: $InputFile"
    exit 1
}

& docker volume inspect $Volume *> $null
if ($LASTEXITCODE -ne 0) {
    log_info "Volume '$Volume' does not exist yet; it will be created"
    & docker volume create $Volume | Out-Null
}

if (-not $AssumeYes) {
    $warning = "This will restore '$InputFile' into volume '$Volume'."
    if ($CleanFlag) {
        $warning = "$warning Its current contents will be erased first."
    }
    log_warn $warning
    $confirm = Read-Host "Continue? [y/N]"
    if ($confirm -notmatch '^[Yy]$') {
        log_info "Aborted."
        exit 0
    }
}

$InputName = Split-Path -Leaf $InputFile

if ($CleanFlag) {
    log_info "Clearing existing contents of volume '$Volume'"
    & docker run --rm -v "${Volume}:/volume" alpine:3.20 `
        sh -c 'find /volume -mindepth 1 -delete'
    if ($LASTEXITCODE -ne 0) {
        log_error "Failed to clear volume '$Volume'"
        exit 1
    }
}

log_info "Restoring '$InputName' into volume '$Volume'"

# Copy the archive into a throwaway container with 'docker cp', then
# extract it there. Unlike a host bind mount, docker cp is streamed over
# the Docker API, so it works even when the Docker daemon doesn't share a
# filesystem with this shell (e.g. Docker Outside of Docker in a
# devcontainer/Codespace).
$containerName = ("restore-$Volume-$(Get-Date -Format 'yyyyMMddHHmmss')" -replace '[^a-zA-Z0-9_.-]', '-')

& docker create --name $containerName -v "${Volume}:/volume" alpine:3.20 `
    tar xzf /tmp/archive.tar.gz -C /volume | Out-Null
if ($LASTEXITCODE -ne 0) {
    log_error "Failed to create restore container for '$Volume'"
    exit 1
}

& docker cp $InputFile "${containerName}:/tmp/archive.tar.gz"
$copyOk = ($LASTEXITCODE -eq 0)

$restoreOk = $false
if ($copyOk) {
    & docker start -a $containerName
    $restoreOk = ($LASTEXITCODE -eq 0)
}
else {
    log_error "Failed to copy '$InputFile' into restore container"
}

& docker rm -f $containerName *> $null

if (-not $restoreOk) {
    log_error "Failed to restore '$Volume' from $InputFile"
    exit 1
}

log_success "Restored '$Volume' from $InputFile"