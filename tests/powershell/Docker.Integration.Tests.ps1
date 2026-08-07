<#
.SYNOPSIS
    Integration tests that run each script for real, but with a fake
    `docker` executable (tests/powershell/mocks/docker) prepended to PATH
    so nothing here needs an actual Docker daemon or Compose stack.

.NOTES
    On Linux/macOS the mock must be executable:
        chmod +x tests/powershell/mocks/docker
#>

BeforeAll {
    $script:RepoRoot   = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:ScriptDir  = Join-Path $RepoRoot 'scripts/powershell'
    $script:HostCmd    = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }
    $script:MockBinDir = Join-Path $PSScriptRoot 'mocks'
    $script:OriginalPath = $env:PATH
    $pathSep = [System.IO.Path]::PathSeparator
    $env:PATH = "$MockBinDir$pathSep$OriginalPath"

    $script:ComposeFile = Join-Path ([System.IO.Path]::GetTempPath()) "compose-$([System.Guid]::NewGuid()).yml"
    Set-Content -Path $ComposeFile -Value @'
services:
  demo:
    image: alpine
'@
}

AfterAll {
    $env:PATH = $OriginalPath
    Remove-Item $ComposeFile -ErrorAction SilentlyContinue
}

Describe 'start.ps1 against a mocked Docker' {
    It 'starts the stack and reports healthy' {
        & $HostCmd -NoProfile -File (Join-Path $ScriptDir 'start.ps1') -f $ComposeFile -p testproj *> $null
        $LASTEXITCODE | Should -Be 0
    }
}

Describe 'health.ps1 against a mocked Docker' {
    It 'reports healthy immediately, no waiting needed' {
        & $HostCmd -NoProfile -File (Join-Path $ScriptDir 'health.ps1') -f $ComposeFile -p testproj *> $null
        $LASTEXITCODE | Should -Be 0
    }
}

Describe 'stop.ps1 against a mocked Docker' {
    It 'stops the stack cleanly' {
        & $HostCmd -NoProfile -File (Join-Path $ScriptDir 'stop.ps1') -f $ComposeFile -p testproj *> $null
        $LASTEXITCODE | Should -Be 0
    }
}

Describe 'restart.ps1 against a mocked Docker' {
    It 'calls stop.ps1 then start.ps1 and exits 0' {
        & $HostCmd -NoProfile -File (Join-Path $ScriptDir 'restart.ps1') -f $ComposeFile -p testproj *> $null
        $LASTEXITCODE | Should -Be 0
    }
}

Describe 'cleanup.ps1 dry run against a mocked Docker' {
    It 'exits 0 without needing -y or removing anything' {
        & $HostCmd -NoProfile -File (Join-Path $ScriptDir 'cleanup.ps1') -f $ComposeFile -p testproj -n *> $null
        $LASTEXITCODE | Should -Be 0
    }
}

Describe 'backup.ps1 against a mocked Docker' {
    BeforeEach {
        $env:MOCK_DOCKER_VOLUMES = 'testproj_data'
        $script:OutDir = Join-Path ([System.IO.Path]::GetTempPath()) "backups-$([System.Guid]::NewGuid())"
    }

    AfterEach {
        Remove-Item Env:\MOCK_DOCKER_VOLUMES -ErrorAction SilentlyContinue
        Remove-Item -Recurse -Force $OutDir -ErrorAction SilentlyContinue
    }

    It 'writes an archive via docker cp for an explicitly named volume' {
        & $HostCmd -NoProfile -File (Join-Path $ScriptDir 'backup.ps1') -p testproj -v testproj_data -o $OutDir *> $null
        $LASTEXITCODE | Should -Be 0
        (Get-ChildItem -Path $OutDir -Filter '*.tar.gz' -ErrorAction SilentlyContinue).Count | Should -BeGreaterThan 0
    }

    It 'fails cleanly when the named volume does not exist' {
        & $HostCmd -NoProfile -File (Join-Path $ScriptDir 'backup.ps1') -p testproj -v does-not-exist -o $OutDir *> $null
        $LASTEXITCODE | Should -Be 1
    }
}

Describe 'restore.ps1 against a mocked Docker' {
    BeforeEach {
        $env:MOCK_DOCKER_VOLUMES = 'testproj_data'
        $script:BackupFile = Join-Path ([System.IO.Path]::GetTempPath()) "restore-src-$([System.Guid]::NewGuid()).tar.gz"
        Set-Content -Path $BackupFile -Value 'fake archive bytes'
    }

    AfterEach {
        Remove-Item Env:\MOCK_DOCKER_VOLUMES -ErrorAction SilentlyContinue
        Remove-Item $BackupFile -ErrorAction SilentlyContinue
    }

    It 'copies the archive into the restore container and exits 0' {
        & $HostCmd -NoProfile -File (Join-Path $ScriptDir 'restore.ps1') -v testproj_data -i $BackupFile -y *> $null
        $LASTEXITCODE | Should -Be 0
    }

    It 'fails cleanly when the input file does not exist' {
        $missing = Join-Path ([System.IO.Path]::GetTempPath()) "no-such-$([System.Guid]::NewGuid()).tar.gz"
        & $HostCmd -NoProfile -File (Join-Path $ScriptDir 'restore.ps1') -v testproj_data -i $missing -y *> $null
        $LASTEXITCODE | Should -Be 1
    }
}
