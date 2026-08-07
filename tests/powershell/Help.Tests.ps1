<#
.SYNOPSIS
    Every script should print usage and exit 0 for -h/--help, without ever
    touching Docker (help is handled inside the arg-parsing loop, before
    the require_docker/require_command preflight checks).
#>

BeforeAll {
    $script:RepoRoot  = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:ScriptDir = Join-Path $RepoRoot 'scripts/powershell'
    $script:HostCmd   = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }
    $script:AllScripts = 'start', 'stop', 'restart', 'health', 'logs', 'backup', 'restore', 'cleanup'
}

Describe '-h prints usage and exits 0' {
    It '<_>.ps1 -h' -ForEach $AllScripts {
        $scriptPath = Join-Path $ScriptDir "$_.ps1"
        $output = & $HostCmd -NoProfile -File $scriptPath -h 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -join "`n") | Should -Match 'Usage:'
    }
}

Describe '--help also works and exits 0' {
    It '<_>.ps1 --help' -ForEach $AllScripts {
        $scriptPath = Join-Path $ScriptDir "$_.ps1"
        & $HostCmd -NoProfile -File $scriptPath --help *> $null
        $LASTEXITCODE | Should -Be 0
    }
}
