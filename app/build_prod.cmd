@if (0)==(0) echo off
@setlocal
@set "SCRIPT_PATH=%~f0"
@powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$path = $env:SCRIPT_PATH; $content = Get-Content -LiteralPath $path -Raw; $marker = ':# POWERSHELL'; $index = $content.LastIndexOf($marker); if ($index -lt 0) { throw 'Missing PowerShell marker.' }; $code = $content.Substring($index + $marker.Length); & ([scriptblock]::Create($code)) @args" %*
@set "EXITCODE=%ERRORLEVEL%"
@exit /b %EXITCODE%
:# POWERSHELL
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $env:SCRIPT_PATH)

$PubspecFile = 'pubspec.yaml'
$AppEnv = 'prod'
$OutputDir = 'build/app/outputs/flutter-apk'
$ApkSplitPerAbi = if ($env:APK_SPLIT_PER_ABI) { $env:APK_SPLIT_PER_ABI } else { '0' }
$DefaultSplitAbi = 'arm64-v8a'
$ApkTargetPlatform = if ($env:APK_TARGET_PLATFORM) { $env:APK_TARGET_PLATFORM } else { 'android-arm64' }
$AppUpdateManifestUrl = if ($env:APP_UPDATE_MANIFEST_URL) { $env:APP_UPDATE_MANIFEST_URL } else { '' }
$AppUpdateUsePackageInstaller = if ($env:APP_UPDATE_USE_PACKAGE_INSTALLER) { $env:APP_UPDATE_USE_PACKAGE_INSTALLER } else { '' }
$BuildMetadataFile = if ($env:BUILD_METADATA_FILE) { $env:BUILD_METADATA_FILE } else { '' }
$ReleaseTag = if ($env:RELEASE_TAG) { $env:RELEASE_TAG } else { '' }
$CiBuildNumber = if ($env:CI_BUILD_NUMBER) { $env:CI_BUILD_NUMBER } else { '' }
$DryRun = $false
$RequestedBuildNumber = ''

function Test-IsNumber {
    param(
        [string]$Value
    )

    return $Value -match '^[0-9]+$'
}

function Get-ReleaseBuildName {
    param(
        [string]$Tag
    )

    $match = [regex]::Match($Tag, '^(?:v)?([0-9]+\.[0-9]+\.[0-9]+(?:-rc[0-9]+)?)$')
    if ($match.Success) {
        return $match.Groups[1].Value
    }

    return $null
}

function Write-Metadata {
    param(
        [string]$Path,
        [string]$BuildName,
        [int]$BuildNumber,
        [string]$ApkRelativePath,
        [string]$ApkFilename,
        [string]$OutputDir,
        [string]$ApkSplitPerAbi,
        [object[]]$AbiOutputs
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    $metadataDir = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($metadataDir)) {
        New-Item -ItemType Directory -Force -Path $metadataDir | Out-Null
    }

    $lines = @(
        "BUILD_NAME=$BuildName"
        "BUILD_NUMBER=$BuildNumber"
        "DISPLAY_VERSION=$BuildName+$BuildNumber"
        "APK_RELATIVE_PATH=$ApkRelativePath"
        "APK_FILENAME=$ApkFilename"
        "OUTPUT_DIR=$OutputDir"
        "APK_SPLIT_PER_ABI=$ApkSplitPerAbi"
    )

    if ($ApkSplitPerAbi -eq '1') {
        foreach ($entry in $AbiOutputs) {
            $abiEnvName = ($entry.Abi.ToUpperInvariant() -replace '-', '_')
            $lines += "APK_RELATIVE_PATH_${abiEnvName}=$OutputDir/$($entry.Filename)"
            $lines += "APK_FILENAME_${abiEnvName}=$($entry.Filename)"
        }
    }

    Set-Content -Path $Path -Value $lines -Encoding ascii
}

if ($args.Count -gt 0 -and $args[0] -eq '--dry-run') {
    $DryRun = $true
    if ($args.Count -gt 1) {
        $RequestedBuildNumber = $args[1]
    }
}
elseif ($args.Count -gt 0) {
    $RequestedBuildNumber = $args[0]
}

if (-not (Test-Path -LiteralPath $PubspecFile)) {
    Write-Host "[ERROR] `"$PubspecFile`" not found."
    exit 1
}

$versionLine = Select-String -Path $PubspecFile -Pattern '^version:' | Select-Object -First 1
if (-not $versionLine) {
    Write-Host "[ERROR] version was not found in `"$PubspecFile`"."
    exit 1
}

$versionValue = (($versionLine.Line -split ':', 2)[1]).Trim()
if ([string]::IsNullOrWhiteSpace($versionValue)) {
    Write-Host "[ERROR] version was not found in `"$PubspecFile`"."
    exit 1
}

$versionParts = $versionValue -split '\+', 2
$BuildName = $versionParts[0]
$PubspecBuildNumber = if ($versionParts.Count -gt 1) { $versionParts[1] } else { '1' }

if ([string]::IsNullOrWhiteSpace($BuildName)) {
    Write-Host "[ERROR] build name could not be parsed from `"$versionValue`"."
    exit 1
}

$TagVersionSource = ''
$TagBuildName = $null
$NormalizedTag = ''

if (-not [string]::IsNullOrWhiteSpace($ReleaseTag)) {
    $NormalizedTag = $ReleaseTag -replace '^refs/tags/', ''
    $TagBuildName = Get-ReleaseBuildName -Tag $NormalizedTag
    if ($TagBuildName) {
        $TagVersionSource = 'release tag'
    }
}

if ($TagBuildName) {
    $BuildName = $TagBuildName
    $BuildNameSource = $TagVersionSource
}
else {
    $BuildNameSource = 'pubspec version'
}

if (-not [string]::IsNullOrWhiteSpace($RequestedBuildNumber)) {
    if (-not (Test-IsNumber $RequestedBuildNumber)) {
        Write-Host "[ERROR] Invalid build number `"$RequestedBuildNumber`"."
        exit 1
    }

    $BuildNumber = [int]$RequestedBuildNumber
    $BuildNumberSource = 'argument'
}
elseif (-not [string]::IsNullOrWhiteSpace($CiBuildNumber)) {
    if (-not (Test-IsNumber $CiBuildNumber)) {
        Write-Host "[ERROR] Invalid CI build number `"$CiBuildNumber`"."
        exit 1
    }

    $BuildNumber = [int]$CiBuildNumber
    $BuildNumberSource = 'ci run number'
}
else {
    if (-not (Test-IsNumber $PubspecBuildNumber)) {
        Write-Host "[ERROR] Invalid pubspec build number `"$PubspecBuildNumber`"."
        exit 1
    }

    $BuildNumber = [int]$PubspecBuildNumber
    $BuildNumberSource = 'pubspec version'
}

if ($BuildNumber -le 0) {
    Write-Host '[ERROR] build number must be greater than 0.'
    exit 1
}

if (-not [string]::IsNullOrWhiteSpace($ReleaseTag) -and -not $TagVersionSource) {
    Write-Host "[ERROR] Unsupported release tag `"$NormalizedTag`"."
    Write-Host '[ERROR] Allowed formats: <version> v<version> <version>-rc<number> v<version>-rc<number>'
    exit 1
}

$AbiOutputs = @()
$BuildArgs = @(
    'apk'
    '--release'
    "--target-platform=$ApkTargetPlatform"
    "--dart-define=APP_ENV=$AppEnv"
    "--build-name=$BuildName"
    "--build-number=$BuildNumber"
)

if (-not [string]::IsNullOrWhiteSpace($AppUpdateManifestUrl)) {
    $BuildArgs += "--dart-define=APP_UPDATE_MANIFEST_URL=$AppUpdateManifestUrl"
}

if (-not [string]::IsNullOrWhiteSpace($AppUpdateUsePackageInstaller)) {
    $BuildArgs += "--dart-define=APP_UPDATE_USE_PACKAGE_INSTALLER=$AppUpdateUsePackageInstaller"
}

if ($ApkSplitPerAbi -eq '1') {
    $BuildArgs += '--split-per-abi'
    $AbiOutputs += [pscustomobject]@{
        Abi = 'arm64-v8a'
        Filename = 'app-arm64-v8a-release.apk'
    }
    $ApkFilename = "app-$DefaultSplitAbi-release.apk"
}
else {
    $ApkFilename = 'app-release.apk'
}

$ApkRelativePath = "$OutputDir/$ApkFilename"

Write-Host ''
Write-Host "Build name   : $BuildName ($BuildNameSource)"
Write-Host "Build number : $BuildNumber ($BuildNumberSource)"
Write-Host "Release tag  : $(if ($ReleaseTag) { $ReleaseTag } else { '<none>' })"
Write-Host "APK file     : $ApkRelativePath"
Write-Host "Output dir   : $OutputDir"
Write-Host "Split per ABI: $ApkSplitPerAbi"
Write-Host "Target ABI   : $ApkTargetPlatform"
Write-Host ''

if ($DryRun) {
    Write-Metadata -Path $BuildMetadataFile -BuildName $BuildName -BuildNumber $BuildNumber -ApkRelativePath $ApkRelativePath -ApkFilename $ApkFilename -OutputDir $OutputDir -ApkSplitPerAbi $ApkSplitPerAbi -AbiOutputs $AbiOutputs
    Write-Host '[DRY RUN] flutter pub get'
    Write-Host "[DRY RUN] flutter build $($BuildArgs -join ' ')"
    exit 0
}

& flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host '[ERROR] flutter pub get failed.'
    exit 1
}

$FlutterBuildArgs = @('build') + $BuildArgs
& flutter @FlutterBuildArgs
if ($LASTEXITCODE -ne 0) {
    Write-Host '[ERROR] flutter build apk failed.'
    exit 1
}

Write-Metadata -Path $BuildMetadataFile -BuildName $BuildName -BuildNumber $BuildNumber -ApkRelativePath $ApkRelativePath -ApkFilename $ApkFilename -OutputDir $OutputDir -ApkSplitPerAbi $ApkSplitPerAbi -AbiOutputs $AbiOutputs

Write-Host ''
Write-Host 'Build finished successfully.'
if (-not [string]::IsNullOrWhiteSpace($BuildMetadataFile)) {
    Write-Host "Build metadata: $BuildMetadataFile"
}
