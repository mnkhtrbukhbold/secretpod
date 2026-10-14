$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'host.ps1') setup @args
exit $LASTEXITCODE
