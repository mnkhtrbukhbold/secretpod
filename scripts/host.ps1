$ErrorActionPreference = 'Stop'
$managerImage = if ($env:SECRETPOD_MANAGER_IMAGE) { $env:SECRETPOD_MANAGER_IMAGE } else { 'ghcr.io/mnkhtrbukhbold/secretpod-manager:0.1.1' }
$operation = if ($args.Count) { $args[0] } else { 'help' }
if ($operation -in @('help', '--help', '-h')) {
    Write-Output 'Usage: host.ps1 setup|up|stop|status|backup|restore|upgrade|trust-cert [--dir PATH] [--url URL] [--image IMAGE] [--http-port PORT] [--backup PATH] [--no-pull]'
    exit 0
}
if ($operation -notin @('setup','up','stop','status','backup','restore','upgrade','trust-cert')) { throw "Unknown operation: $operation" }
$options = @{}
$noPull = $false
for ($i = 1; $i -lt $args.Count; $i++) {
    $option = $args[$i]
    if ($option -eq '--no-pull') { $noPull = $true; continue }
    if ($option -notin @('--dir','--backup','--url','--image','--http-port')) { throw "Unknown option: $option" }
    if (++$i -ge $args.Count -or -not $args[$i]) { throw "Missing value for $option" }
    $options[$option] = $args[$i]
}
if ($operation -in @('backup','restore') -and -not $options['--backup']) { throw '--backup is required.' }
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw 'Install Docker Desktop with Compose v2 first.' }
$endpoint = if ($env:DOCKER_HOST) { $env:DOCKER_HOST } else { & docker context inspect --format '{{.Endpoints.docker.Host}}' }
if ($endpoint -notlike 'npipe:*') { throw 'Use a local Docker Desktop context on Windows. On Linux/macOS use host.sh.' }
$osType = & docker info --format '{{.OSType}}'
if ($LASTEXITCODE -ne 0 -or $osType -ne 'linux') { throw 'Start Docker Desktop and switch to Linux containers.' }
& docker compose version | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Docker Compose v2 is required.' }
function Get-TargetPath([string]$Path) {
    $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    if ($full -notmatch '^[A-Za-z]:\\' -or $full -match '[,\r\n]') { throw 'Use a local drive path without commas or newlines.' }
    $full = $full.TrimEnd('\')
    if ($full.Length -lt 4 -or -not (Test-Path -LiteralPath (Split-Path -Parent $full) -PathType Container)) { throw 'Choose a dedicated directory with an existing parent.' }
    $cursor = $full
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            if ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Symbolic links and junctions are not supported.' }
        }
        $cursor = Split-Path -Parent $cursor
    }
    return $full
}
function New-PrivateDirectory([string]$Path) {
    $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
    $acl = New-Object System.Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true, $false)
    $acl.SetOwner($sid)
    foreach ($identity in @($sid, (New-Object System.Security.Principal.SecurityIdentifier('S-1-5-18')))) {
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($identity, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
        $acl.AddAccessRule($rule)
    }
    # Apply the ACL before the container writes any key or backup.
    [IO.Directory]::CreateDirectory($Path) | Out-Null
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        [IO.FileSystemAclExtensions]::SetAccessControl((Get-Item -LiteralPath $Path), $acl)
    } else { [IO.Directory]::SetAccessControl($Path, $acl) }
}
$installDir = Get-TargetPath $(if ($options['--dir']) { $options['--dir'] } else { Join-Path $HOME 'secretpod' })
if ($operation -eq 'restore' -and (Test-Path -LiteralPath $installDir)) { throw 'Restore destination must not exist.' }
if ($operation -notin @('setup','restore') -and -not (Test-Path -LiteralPath (Join-Path $installDir 'manifest.json'))) { throw 'Installation manifest not found.' }
$backupDir = $null
if ($options['--backup']) {
    $backupDir = Get-TargetPath $options['--backup']
    if ($operation -eq 'backup' -and (Test-Path -LiteralPath $backupDir)) { throw 'Backup destination must not exist.' }
    if ($operation -eq 'restore' -and -not (Test-Path -LiteralPath $backupDir -PathType Container)) { throw 'Backup directory not found.' }
}
if (-not (Test-Path -LiteralPath $installDir) -or
    (Test-Path -LiteralPath (Join-Path $installDir 'manifest.json')) -or
    -not @(Get-ChildItem -LiteralPath $installDir -Force).Count) { New-PrivateDirectory $installDir }
if ($operation -eq 'backup') { New-PrivateDirectory $backupDir }
$daemonDir = '/run/desktop/mnt/host/' + $installDir.Substring(0,1).ToLowerInvariant() + $installDir.Substring(2).Replace('\','/')
$daemonParent = $daemonDir.Substring(0, $daemonDir.LastIndexOf('/'))
$dockerArgs = @('run','--rm','--init',
    '--mount','type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock',
    '--mount',"type=bind,src=$(Split-Path -Parent $installDir),dst=$daemonParent",
    '-e','SECRETPOD_MANAGER=1','-e',"SECRETPOD_CONTAINER_PARENT=$daemonParent",
    '-e',"SECRETPOD_DISPLAY_PARENT=$(Split-Path -Parent $installDir)")
if ($backupDir) {
    $readOnly = if ($operation -eq 'restore') { ',readonly' } else { '' }
    $dockerArgs += @('--mount',"type=bind,src=$(Split-Path -Parent $backupDir),dst=/backup$readOnly",
        '-e',"SECRETPOD_DISPLAY_BACKUP_PARENT=$(Split-Path -Parent $backupDir)")
}
if ($noPull) { $dockerArgs += @('--pull','never') }
$dockerArgs += @($managerImage,$operation,'--dir',$daemonDir)
if ($backupDir) { $dockerArgs += @('--backup',"/backup/$(Split-Path -Leaf $backupDir)") }
foreach ($option in @('--url','--image','--http-port')) {
    if ($options[$option]) { $dockerArgs += @($option,$options[$option]) }
}
if ($noPull) { $dockerArgs += '--no-pull' }
if (-not $noPull -and $operation -in @('setup','up','restore','upgrade')) {
    # The host owns registry credentials and native credential helpers.
    $pullImage = & docker @dockerArgs --print-image
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & docker pull $pullImage
    if ($LASTEXITCODE -eq 0) {
        if ($operation -ne 'upgrade') {
            & docker pull caddy:2.11.2-alpine
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        }
        $dockerArgs += '--no-pull'
    } elseif ($pullImage -notmatch '^ghcr\.io/mnkhtrbukhbold/secretpod:') {
        throw 'Image pull failed. Check your host Docker login and image reference.'
    }
}
& docker @dockerArgs
exit $LASTEXITCODE
