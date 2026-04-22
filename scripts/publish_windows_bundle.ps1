param(
    [string]$Configuration = "Release",
    [string]$Runtime = "win-x64",
    [string]$BackendBuildDir = "build-winlibs"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$distRoot = Join-Path $repoRoot "dist\windows"
$appProject = Join-Path $repoRoot "windows\Vis3D.App\Vis3D.App.csproj"
$installerProject = Join-Path $repoRoot "windows\Vis3D.Installer\Vis3D.Installer.csproj"
$backendDir = Join-Path $repoRoot $BackendBuildDir
$backendExe = Join-Path $backendDir "vis3d_export_demo.exe"

$appPublishDir = Join-Path $distRoot "_app-publish"
$packageDir = Join-Path $distRoot "package"
$installerPublishDir = Join-Path $distRoot "_installer-publish"
$installerExe = Join-Path $distRoot "Vis3DSetup.exe"
$payloadZip = Join-Path $distRoot "Vis3D-payload.zip"
$docsDir = Join-Path $packageDir "docs"

if (-not (Test-Path $backendExe)) {
    throw "Backend executable not found: $backendExe"
}

if (Test-Path $distRoot) {
    Remove-Item -LiteralPath $distRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $distRoot | Out-Null

Write-Host "Publishing Vis3D desktop app..."
dotnet publish $appProject `
    -c $Configuration `
    -r $Runtime `
    --self-contained true `
    /p:PublishSingleFile=true `
    /p:IncludeNativeLibrariesForSelfExtract=true `
    -o $appPublishDir

New-Item -ItemType Directory -Path $packageDir | Out-Null
New-Item -ItemType Directory -Path (Join-Path $packageDir "backend") | Out-Null
New-Item -ItemType Directory -Path $docsDir | Out-Null

Copy-Item -Path (Join-Path $appPublishDir "*") -Destination $packageDir -Recurse -Force
Copy-Item -Path $backendExe -Destination (Join-Path $packageDir "backend") -Force
Copy-Item -Path (Join-Path $backendDir "*.dll") -Destination (Join-Path $packageDir "backend") -Force
Copy-Item -Path (Join-Path $repoRoot "docs\\WINDOWS_GUI.md") -Destination $docsDir -Force

Write-Host "Creating payload archive..."
Compress-Archive -Path (Join-Path $packageDir "*") -DestinationPath $payloadZip -Force

Write-Host "Publishing installer..."
dotnet publish $installerProject `
    -c $Configuration `
    -r $Runtime `
    --self-contained true `
    /p:PublishSingleFile=true `
    /p:IncludeNativeLibrariesForSelfExtract=true `
    /p:PayloadZipPath=$payloadZip `
    -o $installerPublishDir

Copy-Item -LiteralPath (Join-Path $installerPublishDir "Vis3DSetup.exe") -Destination $installerExe -Force

if (Test-Path $appPublishDir) {
    Remove-Item -LiteralPath $appPublishDir -Recurse -Force
}

if (Test-Path $installerPublishDir) {
    Remove-Item -LiteralPath $installerPublishDir -Recurse -Force
}

if (Test-Path $payloadZip) {
    Remove-Item -LiteralPath $payloadZip -Force
}

Write-Host ""
Write-Host "Build complete:"
Write-Host "  App package:      $packageDir"
Write-Host "  Setup exe:        $installerExe"
