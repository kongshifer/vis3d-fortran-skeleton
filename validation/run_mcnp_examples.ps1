param(
    [string]$ExePath = "",
    [string]$CaseDir = ""
)

function Get-VtiCellIds {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $inCellData = $false
    $inCellIdArray = $false
    $values = New-Object 'System.Collections.Generic.HashSet[int]'

    foreach ($line in [System.IO.File]::ReadLines($Path)) {
        if (-not $inCellData) {
            if ($line -match '<CellData\b') {
                $inCellData = $true
            }
            continue
        }

        if (-not $inCellIdArray) {
            if ($line -match '</CellData>') {
                break
            }
            if ($line -match 'Name="cell_id"') {
                $inCellIdArray = $true
            }
            continue
        }

        if ($line -match '</DataArray>') {
            break
        }

        foreach ($match in [regex]::Matches($line, '-?\d+')) {
            [void]$values.Add([int]$match.Value)
        }
    }

    if ($values.Count -eq 0) {
        throw "cell_id array not found in $Path"
    }

    return @($values) | Sort-Object
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
