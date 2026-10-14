$ErrorActionPreference = 'Stop'
$launcher = Join-Path $PSScriptRoot 'start.ps1'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('secretpod-launcher-' + [guid]::NewGuid().ToString('N'))
$names = @('SECRETPOD_MASTER_KEY', 'PODVAULT_MASTER_KEY', 'SECRETPOD_DATA_DIR', 'PODVAULT_DATA_DIR', 'PUB_CACHE')
$saved = @{}
foreach ($name in $names) { $saved[$name] = [Environment]::GetEnvironmentVariable($name); [Environment]::SetEnvironmentVariable($name, $null) }
$failures = 0
function Assert($condition, $message) { if (-not $condition) { throw $message } }
function flutter {
    if ($args[0] -eq 'pub') {
        if ($global:launcherTestDependencyFailure) { $global:LASTEXITCODE = 1; return }
        Set-Content -LiteralPath (Join-Path $global:launcherTestFixture 'dependencies-installed') -Value 'yes'
    } elseif ($args[0] -eq 'build') {
        New-Item -ItemType Directory -Path 'build/web' -Force | Out-Null
        foreach ($file in @('index.html', 'main.dart.js', 'flutter_bootstrap.js')) { Set-Content "build/web/$file" 'new-build' }
    }
    $global:LASTEXITCODE = 0
}
function dart {
    if ($args[0] -eq 'run') {
        Assert (Test-Path (Join-Path $global:launcherTestFixture 'dependencies-installed')) 'Server launched without installing dependencies.'
        Set-Content -LiteralPath (Join-Path $global:launcherTestFixture 'server-started') -Value 'yes'
    }
    $global:LASTEXITCODE = 0
}
function Case($name, [scriptblock]$test) {
    $global:launcherTestFixture = Join-Path $testRoot $name
    $global:launcherTestDependencyFailure = $false
    foreach ($item in $names) { [Environment]::SetEnvironmentVariable($item, $null) }
    New-Item -ItemType Directory -Path "$global:launcherTestFixture/scripts", "$global:launcherTestFixture/secretpod/secretpod_flutter", "$global:launcherTestFixture/secretpod/secretpod_server" -Force | Out-Null
    Copy-Item -LiteralPath $launcher -Destination "$global:launcherTestFixture/scripts/start.ps1"
    try { & $test; Write-Host "PASS: $name" } catch { $script:failures++; Write-Host "FAIL: $name - $($_.Exception.Message)" }
}
function BuiltApp {
    New-Item -ItemType Directory -Path "$global:launcherTestFixture/secretpod/secretpod_server/web/app" -Force | Out-Null
    foreach ($file in @('index.html', 'main.dart.js', 'flutter_bootstrap.js')) { Set-Content "$global:launcherTestFixture/secretpod/secretpod_server/web/app/$file" 'existing-build' }
}
try {
    Case 'skip-installs-dependencies-and-preserves-state' {
        BuiltApp
        $key = [Convert]::ToBase64String((New-Object byte[] 32))
        Set-Content "$global:launcherTestFixture/.env" "SECRETPOD_MASTER_KEY=$key"
        $before = Get-FileHash "$global:launcherTestFixture/.env"
        $env:PUB_CACHE = "$global:launcherTestFixture/custom-cache"
        $env:SECRETPOD_DATA_DIR = "$global:launcherTestFixture/custom-data"
        New-Item -ItemType Directory $env:SECRETPOD_DATA_DIR | Out-Null
        Set-Content "$env:SECRETPOD_DATA_DIR/sentinel" 'preserve'
        & "$global:launcherTestFixture/scripts/start.ps1" -SkipBuild
        Assert ($env:PUB_CACHE -eq "$global:launcherTestFixture/custom-cache") 'PUB_CACHE was overwritten.'
        Assert ((Get-FileHash "$global:launcherTestFixture/.env").Hash -eq $before.Hash) 'Existing key changed.'
        Assert ((Get-Content "$env:SECRETPOD_DATA_DIR/sentinel") -eq 'preserve') 'Existing data changed.'
    }
    Case 'skip-rejects-missing-build' {
        $caught = $false
        try { & "$global:launcherTestFixture/scripts/start.ps1" -SkipBuild } catch { $caught = $_.Exception.Message -match 'build' }
        Assert $caught 'Missing web build was not rejected with useful guidance.'
        Assert (-not (Test-Path "$global:launcherTestFixture/server-started")) 'Server started without web assets.'
    }
    Case 'build-removes-stale-assets' {
        BuiltApp
        Set-Content "$global:launcherTestFixture/secretpod/secretpod_server/web/app/obsolete.js" 'stale'
        & "$global:launcherTestFixture/scripts/start.ps1"
        Assert (-not (Test-Path "$global:launcherTestFixture/secretpod/secretpod_server/web/app/obsolete.js")) 'Old generated asset survived the rebuild.'
        Assert ((Get-Content "$global:launcherTestFixture/secretpod/secretpod_server/web/app/index.html") -eq 'new-build') 'New build was not installed.'
        $before = (Get-FileHash "$global:launcherTestFixture/.env").Hash
        & "$global:launcherTestFixture/scripts/start.ps1" -SkipBuild
        Assert ((Get-FileHash "$global:launcherTestFixture/.env").Hash -eq $before) 'Second launch changed generated key.'
    }
    Case 'dependency-failure-stops-startup' {
        BuiltApp
        $global:launcherTestDependencyFailure = $true
        $caught = $false
        try { & "$global:launcherTestFixture/scripts/start.ps1" -SkipBuild } catch { $caught = $_.Exception.Message -match 'Dependency' }
        Assert $caught 'Dependency failure was not reported.'
        Assert (-not (Test-Path "$global:launcherTestFixture/server-started")) 'Server started after dependency failure.'
    }
    Case 'missing-key-does-not-create-replacement-for-existing-vault' {
        BuiltApp
        New-Item -ItemType Directory "$global:launcherTestFixture/secretpod/secretpod_server/data" | Out-Null
        Set-Content "$global:launcherTestFixture/secretpod/secretpod_server/data/vault.sqlite" 'synthetic-fixture'
        try { & "$global:launcherTestFixture/scripts/start.ps1" -SkipBuild } catch { }
        Assert (-not (Test-Path "$global:launcherTestFixture/.env")) 'A replacement key was generated for an existing vault.'
        Assert (-not (Test-Path "$global:launcherTestFixture/server-started")) 'Existing vault started without its key.'
    }
    Case 'relative-data-directory-uses-terminal-location' {
        BuiltApp
        $env:SECRETPOD_MASTER_KEY = [Convert]::ToBase64String((New-Object byte[] 32))
        $env:SECRETPOD_DATA_DIR = 'relative-data'
        Push-Location $global:launcherTestFixture
        try { & './scripts/start.ps1' -SkipBuild } finally { Pop-Location }
        Assert ($env:SECRETPOD_DATA_DIR -eq (Join-Path $global:launcherTestFixture 'relative-data')) 'Relative data directory was resolved against the process directory instead of the terminal location.'
    }
} finally {
    foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $saved[$name]) }
    $resolved = [IO.Path]::GetFullPath($testRoot)
    $temporary = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolved.StartsWith($temporary, [StringComparison]::OrdinalIgnoreCase)) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
if ($failures -gt 0) { throw "$failures launcher checks failed." }

