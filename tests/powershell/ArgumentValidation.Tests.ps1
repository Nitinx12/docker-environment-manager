<#
.SYNOPSIS
    Argument-parsing edge cases. These all fail inside each script's
    while-loop, before require_docker/require_command run, so no Docker
    (mocked or real) is needed for any test in this file.
#>

BeforeAll {
    $script:RepoRoot  = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:ScriptDir = Join-Path $RepoRoot 'scripts/powershell'
    $script:HostCmd   = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }

    # logs.ps1 is deliberately excluded: unrecognized args are treated as a
    # positional SERVICE name there, not rejected as unknown flags.
    $script:RejectsUnknownFlags = 'start', 'stop', 'restart', 'health', 'backup', 'cleanup', 'restore'
}

Describe 'Unknown options are rejected' {
    It '<_>.ps1 --not-a-real-flag exits 1' -ForEach $RejectsUnknownFlags {
        $scriptPath = Join-Path $ScriptDir "$_.ps1"
        & $HostCmd -NoProfile -File $scriptPath --not-a-real-flag *> $null
        $LASTEXITCODE | Should -Be 1
    }
}

Describe 'logs.ps1 treats an unrecognized arg as a service name, not an error' {
    It 'does not exit 1 purely for having an extra positional arg' {
        # Point at a compose file that doesn't exist so it fails later, for
        # a different, expected reason - not because "myservice" was rejected
        # as an unknown flag.
        $scriptPath = Join-Path $ScriptDir 'logs.ps1'
        $missingCompose = Join-Path ([System.IO.Path]::GetTempPath()) "no-such-$([System.Guid]::NewGuid()).yml"
        $output = & $HostCmd -NoProfile -File $scriptPath -f $missingCompose myservice 2>&1
        ($output -join "`n") | Should -Match 'Compose file not found'
    }
}

Describe 'Flags that require a value fail cleanly when the value is missing' {
    It 'start.ps1 -p with no value exits 1' {
        & $HostCmd -NoProfile -File (Join-Path $ScriptDir 'start.ps1') -p *> $null
        $LASTEXITCODE | Should -Be 1
    }

    It 'backup.ps1 -o with no value exits 1' {
        & $HostCmd -NoProfile -File (Join-Path $ScriptDir 'backup.ps1') -o *> $null
        $LASTEXITCODE | Should -Be 1
    }

    It 'health.ps1 -t with no value exits 1' {
        & $HostCmd -NoProfile -File (Join-Path $ScriptDir 'health.ps1') -t *> $null
        $LASTEXITCODE | Should -Be 1
    }

    It 'restore.ps1 -v with no value exits 1' {
        & $HostCmd -NoProfile -File (Join-Path $ScriptDir 'restore.ps1') -v *> $null
        $LASTEXITCODE | Should -Be 1
    }
}

Describe 'restore.ps1 requires both -v and -i' {
    It 'exits 1 when -i is missing' {
        & $HostCmd -NoProfile -File (Join-Path $ScriptDir 'restore.ps1') -v somevolume -y *> $null
        $LASTEXITCODE | Should -Be 1
    }

    It 'exits 1 when -v is missing' {
        & $HostCmd -NoProfile -File (Join-Path $ScriptDir 'restore.ps1') -i somefile.tar.gz -y *> $null
        $LASTEXITCODE | Should -Be 1
    }
}
