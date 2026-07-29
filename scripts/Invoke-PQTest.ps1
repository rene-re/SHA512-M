[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$sdkVersion = "2.145.5"
$sdkPackageHash = "F330E803BCC0FEDD5E565865857DD29C87074D93962C50FB283CF532110A1890"
$sdkPackageBaseUri =
    "https://api.nuget.org/v3-flatcontainer/microsoft.powerquery.sdktools"
$sdkPackageUri =
    "$sdkPackageBaseUri/$sdkVersion/microsoft.powerquery.sdktools.$sdkVersion.nupkg"

function Write-CiSummary {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string[]] $Lines
    )

    if ($env:GITHUB_STEP_SUMMARY) {
        [System.IO.File]::AppendAllLines(
            $env:GITHUB_STEP_SUMMARY,
            $Lines,
            [System.Text.UTF8Encoding]::new($false)
        )
    }
}

function Get-VerifiedSdkPackage {
    param(
        [Parameter(Mandatory)]
        [string] $CacheDirectory
    )

    New-Item -ItemType Directory -Force -Path $CacheDirectory | Out-Null
    $packagePath = Join-Path $CacheDirectory "Microsoft.PowerQuery.SdkTools.$sdkVersion.nupkg"

    for ($attempt = 1; $attempt -le 2; $attempt++) {
        if (Test-Path -LiteralPath $packagePath) {
            $actualHash = (Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash
            if ($actualHash -eq $sdkPackageHash) {
                return $packagePath
            }

            Write-Warning "Cached SDK package failed SHA-256 verification; removing it."
            Remove-Item -LiteralPath $packagePath -Force
        }

        if ($attempt -eq 2) {
            break
        }

        $downloadPath = "$packagePath.download"
        Remove-Item -LiteralPath $downloadPath -Force -ErrorAction SilentlyContinue
        Write-Host "Downloading Microsoft.PowerQuery.SdkTools $sdkVersion..."
        Invoke-WebRequest -Uri $sdkPackageUri -OutFile $downloadPath
        Move-Item -LiteralPath $downloadPath -Destination $packagePath
    }

    throw "Microsoft.PowerQuery.SdkTools $sdkVersion did not match the pinned SHA-256 hash."
}

try {
    if (-not $IsWindows) {
        throw (
            "PQTest local execution requires Windows. Use the repository's " +
            "GitHub Actions workflow on other operating systems."
        )
    }

    if ($PSVersionTable.PSVersion.Major -lt 7) {
        throw "Invoke-PQTest.ps1 requires PowerShell 7 or newer."
    }

    $repositoryRoot = Split-Path -Parent $PSScriptRoot
    $artifactsRoot = Join-Path $repositoryRoot ".artifacts\pqtest"
    $expectedArtifactsRoot = [System.IO.Path]::GetFullPath(
        (Join-Path $repositoryRoot ".artifacts\pqtest")
    )
    $resolvedArtifactsRoot = [System.IO.Path]::GetFullPath($artifactsRoot)

    if ($resolvedArtifactsRoot -ne $expectedArtifactsRoot) {
        throw "Refusing to clean an unexpected artifacts path: $resolvedArtifactsRoot"
    }

    if (Test-Path -LiteralPath $artifactsRoot) {
        Remove-Item -LiteralPath $artifactsRoot -Recurse -Force
    }

    $sourceDirectory = Join-Path $artifactsRoot "source"
    $buildDirectory = Join-Path $artifactsRoot "bin"
    $toolsDirectory = Join-Path $artifactsRoot "sdk-tools"
    New-Item -ItemType Directory -Force -Path $sourceDirectory, $buildDirectory | Out-Null

    $cacheRoot = if ($env:PQTEST_SDK_CACHE) {
        $env:PQTEST_SDK_CACHE
    }
    else {
        Join-Path $env:LOCALAPPDATA "SHA512-M\SdkTools"
    }

    $packageCache = Join-Path $cacheRoot $sdkVersion
    $packagePath = Get-VerifiedSdkPackage -CacheDirectory $packageCache

    Write-Host "Expanding the verified SDK package..."
    [System.IO.Compression.ZipFile]::ExtractToDirectory($packagePath, $toolsDirectory)

    $libraryPath = Join-Path $repositoryRoot "SHA512_M.pq"
    $librarySource = [System.IO.File]::ReadAllText($libraryPath)
    $connectorSource = @"
section SHA512MTest;
shared SHA512_M =
$($librarySource.TrimEnd());
"@
    $generatedSourcePath = Join-Path $sourceDirectory "SHA512MTest.pq"
    [System.IO.File]::WriteAllText(
        $generatedSourcePath,
        $connectorSource,
        [System.Text.UTF8Encoding]::new($false)
    )

    $makePqxPath = Join-Path $toolsDirectory "tools\MakePQX.exe"
    $pqTestPath = Join-Path $toolsDirectory "tools\PQTest.exe"
    $compileLogPath = Join-Path $artifactsRoot "makepqx.log"

    Write-Host "Compiling the test-only connector..."
    $compileOutput = & $makePqxPath compile $sourceDirectory `
        --directory $buildDirectory `
        --target "SHA512MTest" 2>&1
    $compileExitCode = $LASTEXITCODE
    $compileOutputText = ($compileOutput | Out-String)
    [System.IO.File]::WriteAllText(
        $compileLogPath,
        $compileOutputText,
        [System.Text.UTF8Encoding]::new($false)
    )

    if ($compileExitCode -ne 0) {
        throw "MakePQX failed with exit code $compileExitCode. See $compileLogPath."
    }

    $mezPath = Join-Path $buildDirectory "SHA512MTest.mez"
    if (-not (Test-Path -LiteralPath $mezPath)) {
        throw "MakePQX reported success but did not create $mezPath."
    }

    $testDirectory = Join-Path $repositoryRoot "tests\pqtest"
    $expectedTests = @(
        Get-ChildItem -LiteralPath $testDirectory -File -Filter "*.query.pq" |
            Sort-Object Name |
            Select-Object -ExpandProperty Name
    )
    if ($expectedTests.Count -eq 0) {
        throw "No PQTest query files were found in $testDirectory."
    }

    $resultsPath = Join-Path $artifactsRoot "pqtest-results.json"
    Write-Host "Running $($expectedTests.Count) PQTest query groups..."
    $pqTestOutput = & $pqTestPath run-test `
        -e $mezPath `
        -q $testDirectory `
        -p 2>&1
    $pqTestExitCode = $LASTEXITCODE
    $rawResults = ($pqTestOutput | Out-String).Trim()
    [System.IO.File]::WriteAllText(
        $resultsPath,
        $rawResults,
        [System.Text.UTF8Encoding]::new($false)
    )

    if ($pqTestExitCode -ne 0) {
        throw "PQTest failed with exit code $pqTestExitCode. See $resultsPath."
    }

    try {
        $parsedResults = @($rawResults | ConvertFrom-Json)
    }
    catch {
        throw "PQTest returned invalid JSON. See $resultsPath. $($_.Exception.Message)"
    }

    if ($parsedResults.Count -eq 0) {
        throw "PQTest returned no test results."
    }

    $resultNames = @($parsedResults | ForEach-Object { [string] $_.Name })
    $duplicateNames = @(
        $resultNames |
            Group-Object |
            Where-Object Count -gt 1 |
            Select-Object -ExpandProperty Name
    )
    $missingNames = @($expectedTests | Where-Object { $_ -notin $resultNames })
    $unexpectedNames = @($resultNames | Where-Object { $_ -notin $expectedTests })
    $failedResults = @($parsedResults | Where-Object Status -ne "Passed")

    $displayResults = $parsedResults |
        Sort-Object Name |
        Select-Object Name, Status, @{
            Name = "Duration"
            Expression = {
                $start = [datetimeoffset] $_.StartTime
                $end = [datetimeoffset] $_.EndTime
                "{0:N1}s" -f ($end - $start).TotalSeconds
            }
        }
    $displayResults | Format-Table -AutoSize

    $validationProblems = @()
    if ($duplicateNames.Count -gt 0) {
        $validationProblems += "Duplicate results: $($duplicateNames -join ', ')"
    }
    if ($missingNames.Count -gt 0) {
        $validationProblems += "Missing results: $($missingNames -join ', ')"
    }
    if ($unexpectedNames.Count -gt 0) {
        $validationProblems += "Unexpected results: $($unexpectedNames -join ', ')"
    }
    if ($failedResults.Count -gt 0) {
        $validationProblems += "$($failedResults.Count) query group(s) failed."
    }

    $passedCount = @($parsedResults | Where-Object Status -eq "Passed").Count
    $summaryLines = @(
        "## PQTest",
        "",
        "- SDK Tools: ``$sdkVersion``",
        "- Query groups: $($parsedResults.Count)",
        "- Passed: $passedCount",
        "- Failed: $($failedResults.Count)",
        "",
        "| Query group | Status |",
        "| --- | --- |"
    )
    foreach ($result in ($parsedResults | Sort-Object Name)) {
        $summaryLines += "| ``$($result.Name)`` | $($result.Status) |"
    }
    Write-CiSummary -Lines $summaryLines

    if ($validationProblems.Count -gt 0) {
        foreach ($problem in $validationProblems) {
            Write-Error $problem -ErrorAction Continue
        }

        foreach ($failed in $failedResults) {
            Write-Host ""
            Write-Host "Failure: $($failed.Name)"
            if ($failed.PSObject.Properties.Name -contains "Error") {
                $failed.Error | ConvertTo-Json -Depth 20
            }
        }

        exit 1
    }

    Write-Host "All PQTest query groups passed."
    exit 0
}
catch {
    $message = $_.Exception.Message
    Write-CiSummary -Lines @(
        "## PQTest",
        "",
        "**Infrastructure failure:** $message"
    )
    Write-Error $message
    exit 1
}
