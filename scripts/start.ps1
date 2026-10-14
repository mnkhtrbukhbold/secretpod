param([switch]$SkipBuild)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
foreach ($tool in @('flutter', 'dart')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "Missing $tool. Install Flutter 3.47.7 (includes Dart 3.13.5), add Flutter's bin directory to PATH, then reopen your terminal. See docs/development.md."
    }
}
if (-not $env:PUB_CACHE) { $env:PUB_CACHE = Join-Path $projectRoot '.cache/pub' }
$destination = Join-Path $projectRoot 'secretpod/secretpod_server/web/app'
if ($SkipBuild) {
    foreach ($asset in @('index.html', 'main.dart.js', 'flutter_bootstrap.js')) {
        if (-not (Test-Path -LiteralPath (Join-Path $destination $asset) -PathType Leaf)) {
            throw 'No complete web build exists. Run scripts/start.ps1 without -SkipBuild first.'
        }
    }
}
if (-not $env:SECRETPOD_DATA_DIR) {
    $env:SECRETPOD_DATA_DIR = if ($env:PODVAULT_DATA_DIR) { $env:PODVAULT_DATA_DIR } else { Join-Path $projectRoot 'secretpod/secretpod_server/data' }
}
$env:SECRETPOD_DATA_DIR = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($env:SECRETPOD_DATA_DIR)
$environmentFile = Join-Path $projectRoot '.env'
if (-not $env:SECRETPOD_MASTER_KEY) {
    $env:SECRETPOD_MASTER_KEY = $env:PODVAULT_MASTER_KEY
}
if (-not $env:SECRETPOD_MASTER_KEY) {
    if (-not (Test-Path -LiteralPath $environmentFile)) {
        if ((Test-Path -LiteralPath (Join-Path $env:SECRETPOD_DATA_DIR 'vault.sqlite')) -or (Test-Path -LiteralPath (Join-Path $env:SECRETPOD_DATA_DIR 'vault.json'))) {
            throw 'An existing vault has no configured master key. Restore its matching .env or set SECRETPOD_MASTER_KEY; a replacement key cannot decrypt existing data.'
        }
        $bytes = New-Object byte[] 32
        $generator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        $generator.GetBytes($bytes)
        $generator.Dispose()
        [System.IO.File]::WriteAllText($environmentFile, 'SECRETPOD_MASTER_KEY=' + [Convert]::ToBase64String($bytes) + [Environment]::NewLine)
        Write-Host 'Created the local master key in .env. Keep this file with your backups.'
    }
    $environmentLines = Get-Content -LiteralPath $environmentFile
    $keyLine = $environmentLines | Where-Object { $_.StartsWith('SECRETPOD_MASTER_KEY=') } | Select-Object -First 1
    if (-not $keyLine) {
        $keyLine = $environmentLines | Where-Object { $_.StartsWith('PODVAULT_MASTER_KEY=') } | Select-Object -First 1
    }
    if (-not $keyLine) { throw 'The .env file does not contain SECRETPOD_MASTER_KEY.' }
    $env:SECRETPOD_MASTER_KEY = $keyLine.Substring($keyLine.IndexOf('=') + 1).Trim()
}
try { $keyBytes = [Convert]::FromBase64String($env:SECRETPOD_MASTER_KEY) } catch { throw 'SECRETPOD_MASTER_KEY must be a base64-encoded 32-byte key.' }
if ($keyBytes.Length -ne 32) { throw 'SECRETPOD_MASTER_KEY must be a base64-encoded 32-byte key.' }
Push-Location (Join-Path $projectRoot 'secretpod')
try {
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Dependency installation failed. Check your Flutter version and network connection; see docs/development.md.' }
} finally { Pop-Location }
if (-not $SkipBuild) {
    Push-Location (Join-Path $projectRoot 'secretpod/secretpod_flutter')
    try {
        flutter build web --no-web-resources-cdn
        if ($LASTEXITCODE -ne 0) { throw 'Flutter build failed.' }
        # Only replace the generated app after the complete new build succeeds.
        $expected = [IO.Path]::GetFullPath((Join-Path $projectRoot 'secretpod/secretpod_server/web/app'))
        if ([IO.Path]::GetFullPath($destination) -ne $expected) { throw 'Unexpected web output directory.' }
        if (Test-Path -LiteralPath $destination) { Remove-Item -LiteralPath $destination -Recurse -Force }
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
        Copy-Item -Path 'build/web/*' -Destination $destination -Recurse -Force
    } finally { Pop-Location }
}
Push-Location (Join-Path $projectRoot 'secretpod/secretpod_server')
try {
    $webPort = if ($env:SERVERPOD_WEB_SERVER_PORT) { $env:SERVERPOD_WEB_SERVER_PORT } else { '8082' }
    Write-Host "SecretPod: http://localhost:$webPort - press Ctrl+C to stop."
    dart run bin/main.dart --mode development
    if ($LASTEXITCODE -ne 0) { throw 'Server stopped with an error.' }
} finally { Pop-Location }
