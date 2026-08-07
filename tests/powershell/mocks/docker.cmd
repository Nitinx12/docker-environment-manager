@echo off
REM Windows shim for the bash-based docker mock in this folder.
REM PowerShell's command resolution never finds an extensionless file, so
REM this .cmd (picked up via the default PATHEXT) delegates to the same
REM mock logic through Git Bash, which GitHub-hosted windows-latest
REM runners ship with (it's how `shell: bash` steps work there too).
bash "%~dp0docker" %*
