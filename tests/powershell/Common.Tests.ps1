<#
.SYNOPSIS
    Unit tests for scripts/powershell/lib/common.ps1.

.DESCRIPTION
    Run with: Invoke-Pester -Path ./tests/powershell -Output Detailed
    Requires Pester 5+: Install-Module -Name Pester -MinimumVersion 5.5.0 -Scope CurrentUser
#>

BeforeAll {
    $script:RepoRoot  = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:ScriptDir = Join-Path $RepoRoot 'scripts/powershell'
    $script:HostCmd   = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }

    # Dot-sourcing is safe here: common.ps1 only *defines* functions and
    # computes $RepoRoot at load time. It never calls exit on its own.
    . (Join-Path $ScriptDir 'lib/common.ps1')
}

Describe 'Resolve-UnderRepoRoot' {
    It 'returns an absolute path unchanged' {
        $abs = if ($IsWindows) { 'C:\some\abs\path' } else { '/some/abs/path' }
        Resolve-UnderRepoRoot $abs | Should -Be $abs
    }

    It 'joins a bare relative path under the repo root' {
        Resolve-UnderRepoRoot 'backups' | Should -Be (Join-Path $RepoRoot 'backups')
    }

    It 'joins a relative path with subfolders under the repo root' {
        Resolve-UnderRepoRoot 'docker/docker-compose.yml' | Should -Be (Join-Path $RepoRoot 'docker/docker-compose.yml')
    }
}

Describe 'load_env' {
    BeforeEach {
        $script:TempEnvDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid())
        New-Item -ItemType Directory -Path $TempEnvDir | Out-Null
        $script:SavedRepoRoot = $RepoRoot
    }

    AfterEach {
        Set-Variable -Name RepoRoot -Value $SavedRepoRoot -Scope Script
        Remove-Item -Recurse -Force $TempEnvDir -ErrorAction SilentlyContinue
        Remove-Variable -Name TEST_KEY -Scope Global -ErrorAction SilentlyContinue
        Remove-Variable -Name QUOTED_KEY -Scope Global -ErrorAction SilentlyContinue
    }

    It 'sets a global variable for each KEY=VALUE line' {
        Set-Content -Path (Join-Path $TempEnvDir '.env') -Value 'TEST_KEY=hello'
        Set-Variable -Name RepoRoot -Value $TempEnvDir -Scope Script
        load_env
        $global:TEST_KEY | Should -Be 'hello'
    }

    It 'strips matching surrounding quotes' {
        Set-Content -Path (Join-Path $TempEnvDir '.env') -Value 'QUOTED_KEY="hello world"'
        Set-Variable -Name RepoRoot -Value $TempEnvDir -Scope Script
        load_env
        $global:QUOTED_KEY | Should -Be 'hello world'
    }

    It 'ignores comments and blank lines' {
        Set-Content -Path (Join-Path $TempEnvDir '.env') -Value @('# a comment', '', 'TEST_KEY=value')
        Set-Variable -Name RepoRoot -Value $TempEnvDir -Scope Script
        load_env
        $global:TEST_KEY | Should -Be 'value'
    }

    It 'does nothing when no .env file exists' {
        Set-Variable -Name RepoRoot -Value $TempEnvDir -Scope Script
        { load_env } | Should -Not -Throw
    }
}

Describe 'require_command' {
    It 'does not exit when the command exists' {
        { require_command $HostCmd } | Should -Not -Throw
    }

    It 'exits with code 1 (in a child process) when the command does not exist' {
        $probeSrc = @"
`$ScriptDir = '$ScriptDir'
. (Join-Path `$ScriptDir 'lib/common.ps1')
require_command 'definitely-not-a-real-command-xyz'
"@
        $probePath = Join-Path ([System.IO.Path]::GetTempPath()) "probe-$([System.Guid]::NewGuid()).ps1"
        Set-Content -Path $probePath -Value $probeSrc

        & $HostCmd -NoProfile -File $probePath *> $null
        $exitCode = $LASTEXITCODE

        Remove-Item $probePath -ErrorAction SilentlyContinue
        $exitCode | Should -Be 1
    }
}
