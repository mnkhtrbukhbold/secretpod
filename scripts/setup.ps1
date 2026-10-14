$ErrorActionPreference = 'Stop'
if (Get-Command python -ErrorAction SilentlyContinue) { $python = 'python' }
elseif (Get-Command python3 -ErrorAction SilentlyContinue) { $python = 'python3' }
else { throw 'Install Python 3.10 or newer, then retry.' }
& $python (Join-Path $PSScriptRoot 'host.py') setup @args
exit $LASTEXITCODE
