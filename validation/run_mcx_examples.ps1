param(
    [string]$ExePath = "",
    [string]$CaseDir = ""
)

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ExePath)) {
    $ExePath = Join-Path $repoRoot "build-winlibs\vis3d_export_demo.exe"
}
if ([string]::IsNullOrWhiteSpace($CaseDir)) {
    $CaseDir = Join-Path $PSScriptRoot "mcx_examples"
}

$cases = @(
    "pool.xml",
    "2G.xml",
    "VERA_1b.xml",
    "c5g7.xml",
    "pebble.xml"
)

if (-not (Test-Path $ExePath)) {
    throw "Executable not found: $ExePath"
}

foreach ($case in $cases) {
    $inputPath = Join-Path $CaseDir $case
    $outputPath = [System.IO.Path]::ChangeExtension($inputPath, ".vtp")

    if (-not (Test-Path $inputPath)) {
        throw "Validation case missing: $inputPath"
    }

    if (Test-Path $outputPath) {
        Remove-Item $outputPath -Force
    }

    & $ExePath $inputPath mcx
    if ($LASTEXITCODE -ne 0) {
        throw "VIS3D export failed for $case"
    }
    if (-not (Test-Path $outputPath)) {
        throw "Expected output not generated: $outputPath"
    }

    $item = Get-Item $outputPath
    Write-Host ("OK  {0,-12} -> {1} bytes" -f $case, $item.Length)
}
