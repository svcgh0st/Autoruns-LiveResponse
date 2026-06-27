[CmdletBinding()]
param(
    [string]$AutorunscPath,
    [string]$OutputCsv,
    [string[]]$Ignore = @(),
    [string]$IgnoreFile,
    [ValidateSet('All', 'Signed', 'Unsigned')]
    [string]$SignatureFilter = 'All',
    [int]$RecentDays = 0,
    [switch]$DropEmptyRows,
    [switch]$HideMicrosoft
)

$ErrorActionPreference = 'Stop'

if (-not $OutputCsv) {
    $OutputCsv = Join-Path $PSScriptRoot 'autoruns.csv'
}

if (-not $AutorunscPath) {
    $localCandidates = @(
        (Join-Path $PSScriptRoot 'autorunsc64.exe'),
        (Join-Path $PSScriptRoot 'autorunsc.exe'),
        (Join-Path $PSScriptRoot 'tools\autorunsc64.exe'),
        (Join-Path $PSScriptRoot 'tools\autorunsc.exe')
    )

    $AutorunscPath = $localCandidates |
        Where-Object { Test-Path -LiteralPath $_ } |
        Select-Object -First 1

    if (-not $AutorunscPath) {
        $command = Get-Command 'autorunsc64.exe', 'autorunsc.exe' -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($command) {
            $AutorunscPath = $command.Source
        }
    }

    if (-not $AutorunscPath) {
        throw 'Autorunsc was not found. Put autorunsc64.exe next to this script, put it in a tools folder, install Microsoft Sysinternals Autoruns, or pass -AutorunscPath.'
    }
}

$AutorunscPath = (Resolve-Path -LiteralPath $AutorunscPath).Path

if ($IgnoreFile) {
    $IgnoreFile = (Resolve-Path -LiteralPath $IgnoreFile).Path
    $Ignore += Get-Content -LiteralPath $IgnoreFile |
        Where-Object { $_.Trim() -and -not $_.Trim().StartsWith('#') } |
        ForEach-Object { $_.Trim() }
}

$outputDirectory = Split-Path -Parent $OutputCsv
if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$rawCsv = Join-Path ([System.IO.Path]::GetTempPath()) ("autoruns-{0}.csv" -f [guid]::NewGuid())
$errorLog = Join-Path ([System.IO.Path]::GetTempPath()) ("autoruns-{0}.log" -f [guid]::NewGuid())

function ConvertTo-AutorunsDate {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    $styles = [System.Globalization.DateTimeStyles]::AssumeLocal
    $cultures = @(
        [System.Globalization.CultureInfo]::CurrentCulture,
        [System.Globalization.CultureInfo]::GetCultureInfo('en-AU'),
        [System.Globalization.CultureInfo]::GetCultureInfo('en-US'),
        [System.Globalization.CultureInfo]::InvariantCulture
    )

    foreach ($culture in $cultures) {
        try {
            return [datetime]::Parse($Value, $culture, $styles)
        }
        catch {
            continue
        }
    }

    $parsed = [datetime]::MinValue
    if ([datetime]::TryParseExact($Value, 'yyyyMMdd-HHmmss', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal, [ref]$parsed)) {
        return $parsed.ToLocalTime()
    }

    return $null
}

try {
    $arguments = @('-accepteula', '-nobanner', '-a', '*', '-c', '-h', '-s')
    if ($SignatureFilter -eq 'Unsigned') {
        $arguments += '-u'
    }
    if ($HideMicrosoft) {
        $arguments += '-m'
    }

    & $AutorunscPath @arguments 2> $errorLog | Set-Content -LiteralPath $rawCsv -Encoding utf8
    if ($LASTEXITCODE -ne 0) {
        $details = (Get-Content -LiteralPath $errorLog -Raw -ErrorAction SilentlyContinue).Trim()
        throw "Autorunsc failed with exit code $LASTEXITCODE. $details"
    }

    $rows = @(Import-Csv -LiteralPath $rawCsv)
    if ($SignatureFilter -eq 'Signed') {
        $rows = @($rows | Where-Object { $_.Signer -like '(Verified)*' })
    }

    if ($RecentDays -gt 0) {
        $cutoff = (Get-Date).AddDays(-$RecentDays)
        $rows = @($rows | Where-Object {
            $entryTime = ConvertTo-AutorunsDate -Value $_.Time
            $entryTime -and $entryTime -ge $cutoff
        })
    }

    if ($DropEmptyRows) {
        $rows = @($rows | Where-Object {
            -not (
                [string]::IsNullOrWhiteSpace($_.Entry) -and
                [string]::IsNullOrWhiteSpace($_.'Image Path') -and
                [string]::IsNullOrWhiteSpace($_.'Launch String') -and
                [string]::IsNullOrWhiteSpace($_.Description) -and
                [string]::IsNullOrWhiteSpace($_.Company) -and
                [string]::IsNullOrWhiteSpace($_.Signer)
            )
        })
    }

    if ($Ignore.Count -gt 0) {
        $rows = @($rows | Where-Object {
            $combinedFields = ($_.PSObject.Properties.Value | ForEach-Object { [string]$_ }) -join "`n"
            $matched = $false
            foreach ($pattern in $Ignore) {
                if ($combinedFields.IndexOf($pattern, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                    $matched = $true
                    break
                }
            }
            -not $matched
        })
    }

    $rows | Export-Csv -LiteralPath $OutputCsv -NoTypeInformation -Encoding utf8
    $resolvedOutput = (Resolve-Path -LiteralPath $OutputCsv).Path
    Write-Host "Saved $($rows.Count) Autoruns entries to $resolvedOutput"
}
finally {
    Remove-Item -LiteralPath $rawCsv, $errorLog -Force -ErrorAction SilentlyContinue
}
