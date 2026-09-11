# Evim Automated Flutter Setup Script
$ErrorActionPreference = 'Stop'

Write-Host '=========================================='
Write-Host '   Evim - Flutter SDK Automated Setup     '
Write-Host '=========================================='

# Step 1: Git check
Write-Host '[1/4] Checking Git installation...'
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCmd) {
    Write-Host 'Installing Git via winget...'
    winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements
    $gitPath = 'C:\Program Files\Git\cmd'
    if (Test-Path $gitPath) {
        $env:Path = $gitPath + ';' + $env:Path
    }
} else {
    Write-Host 'Git is available.'
}

# Step 2: Download & Extract Flutter
$targetDir = 'C:\src'
$flutterDir = 'C:\src\flutter'
$flutterBin = 'C:\src\flutter\bin'
$flutterBat = 'C:\src\flutter\bin\flutter.bat'

if (Test-Path $flutterBat) {
    Write-Host 'Flutter SDK already present at ' + $flutterDir
} else {
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    $zipFile = 'C:\src\flutter_windows.zip'
    $downloadUrl = 'https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.47.3-stable.zip'

    Write-Host '[2/4] Downloading Flutter SDK bundle (~1.1 GB)...'
    Write-Host $downloadUrl

    if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
        & curl.exe -L -o $zipFile $downloadUrl
    } else {
        Start-BitsTransfer -Source $downloadUrl -Destination $zipFile
    }

    Write-Host '[3/4] Extracting Flutter SDK to C:\src...'
    Expand-Archive -Path $zipFile -DestinationPath $targetDir -Force
    Remove-Item $zipFile -Force
    Write-Host 'Extraction complete.'
}

# Step 3: Configure PATH
Write-Host '[4/4] Setting User Environment PATH...'
$userPath = [Environment]::GetEnvironmentVariable('Path', [EnvironmentVariableTarget]::User)
if ($userPath -notlike ('*' + $flutterBin + '*')) {
    [Environment]::SetEnvironmentVariable('Path', $flutterBin + ';' + $userPath, [EnvironmentVariableTarget]::User)
    Write-Host 'Added ' + $flutterBin + ' to User PATH.'
}
$env:Path = $flutterBin + ';' + $env:Path

Write-Host '=========================================='
Write-Host 'Flutter SDK Setup Completed!'
Write-Host '=========================================='
