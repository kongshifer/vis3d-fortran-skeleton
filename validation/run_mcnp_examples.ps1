param(
    [string]$ExePath = "",
    [string]$CaseDir = ""
)

function Get-VtiCellIds {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $text = Get-Content -LiteralPath $Path -Raw
    $match = [regex]::Match(
        $text,
        'Name="cell_id"[^>]*>\s*(.*?)\s*</DataArray>',
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
    if (-not $match.Success) {
        throw "cell_id array not found in $Path"
    }

    return [regex]::Matches($match.Groups[1].Value, '-?\d+') |
        ForEach-Object { [int]$_.Value } |
        Sort-Object -Unique
}

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ExePath)) {
    $ExePath = Join-Path $repoRoot "build-winlibs\vis3d_export_demo.exe"
}
if ([string]::IsNullOrWhiteSpace($CaseDir)) {
    $CaseDir = Join-Path $PSScriptRoot "mcnp_examples"
}

$cases = @(
    @{
        Name = "angle/inp"
        RelativeInput = "angle\inp"
        ExpectedCellIds = @(1, 2, 11, 12)
    },
    @{
        Name = "point_ring_detector/inpdet"
        RelativeInput = "point_ring_detector\inpdet"
        ExpectedCellIds = @(1, 2, 3, 4, 7)
    }
)

if (-not (Test-Path $ExePath)) {
    throw "Executable not found: $ExePath"
}

foreach ($case in $cases) {
    $inputPath = Join-Path $CaseDir $case.RelativeInput
    $outputPath = "$inputPath.vti"

    if (-not (Test-Path $inputPath)) {
        throw "Validation case missing: $inputPath"
    }

    if (Test-Path $outputPath) {
        Remove-Item -LiteralPath $outputPath -Force
    }

    & $ExePath $inputPath mcnp
    if ($LASTEXITCODE -ne 0) {
        throw "VIS3D export failed for $($case.Name)"
    }
    if (-not (Test-Path $outputPath)) {
        throw "Expected output not generated: $outputPath"
    }

    $actualCellIds = @(Get-VtiCellIds -Path $outputPath)
    $missing = @($case.ExpectedCellIds | Where-Object { $actualCellIds -notcontains $_ })
    if ($missing.Count -gt 0) {
        throw "Missing expected cell_id(s) for $($case.Name): $($missing -join ', ')"
    }

    $item = Get-Item -LiteralPath $outputPath
    Write-Host ("OK  {0,-28} -> {1} bytes, cell_id: {2}" -f $case.Name, $item.Length, ($actualCellIds -join ', '))
}
