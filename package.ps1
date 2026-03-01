# Local packaging wrapper for the official BigWigs packager.

param(
    [string]$OutputDir = ".\.release"
)

$ErrorActionPreference = "Stop"

function Get-FullPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$BasePath
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $BasePath $Path))
}

function Escape-BashLiteral {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $replacement = "'" + '"' + "'" + '"' + "'"
    return "'" + ($Value -replace "'", $replacement) + "'"
}

function New-PackagerScript {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRootUnix,
        [Parameter(Mandatory = $true)]
        [string]$ReleaseDirUnix
    )

    $script = @'
set -euo pipefail
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
curl -fsSL __PACKAGER_URL__ -o "$tmp_dir/release.sh"
chmod +x "$tmp_dir/release.sh"
cd __REPO_ROOT__
"$tmp_dir/release.sh" -d -r __RELEASE_DIR__
'@

    $script = $script.Replace("__PACKAGER_URL__", (Escape-BashLiteral "https://raw.githubusercontent.com/BigWigsMods/packager/master/release.sh"))
    $script = $script.Replace("__REPO_ROOT__", (Escape-BashLiteral $RepoRootUnix))
    $script = $script.Replace("__RELEASE_DIR__", (Escape-BashLiteral $ReleaseDirUnix))
    return $script
}

function Try-InvokeWslPackager {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,
        [Parameter(Mandatory = $true)]
        [string]$ReleaseDir
    )

    $wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
    if (-not $wsl) {
        return $false
    }

    & $wsl.Source -e bash -lc "command -v curl >/dev/null && command -v zip >/dev/null"
    if ($LASTEXITCODE -ne 0) {
        return $false
    }

    $repoRootUnix = (& $wsl.Source wslpath -a $RepoRoot | Out-String).Trim()
    $releaseDirUnix = (& $wsl.Source wslpath -a $ReleaseDir | Out-String).Trim()
    $script = New-PackagerScript -RepoRootUnix $repoRootUnix -ReleaseDirUnix $releaseDirUnix

    Write-Host "Running official packager through WSL..." -ForegroundColor Cyan
    & $wsl.Source -e bash -lc $script
    if ($LASTEXITCODE -ne 0) {
        throw "The official packager failed while running under WSL."
    }

    return $true
}

function Try-InvokeGitBashPackager {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,
        [Parameter(Mandatory = $true)]
        [string]$ReleaseDir
    )

    $bash = Get-Command bash.exe -ErrorAction SilentlyContinue
    if (-not $bash) {
        $bash = Get-Command bash -ErrorAction SilentlyContinue
    }

    if (-not $bash) {
        return $false
    }

    & $bash.Source -lc "command -v curl >/dev/null && command -v zip >/dev/null && command -v cygpath >/dev/null"
    if ($LASTEXITCODE -ne 0) {
        return $false
    }

    $repoRootUnix = (& $bash.Source -lc ("cygpath -au " + (Escape-BashLiteral $RepoRoot)) | Out-String).Trim()
    $releaseDirUnix = (& $bash.Source -lc ("cygpath -au " + (Escape-BashLiteral $ReleaseDir)) | Out-String).Trim()
    $script = New-PackagerScript -RepoRootUnix $repoRootUnix -ReleaseDirUnix $releaseDirUnix

    Write-Host "Running official packager through Git Bash..." -ForegroundColor Cyan
    & $bash.Source -lc $script
    if ($LASTEXITCODE -ne 0) {
        throw "The official packager failed while running under Git Bash."
    }

    return $true
}

if (-not (Test-Path ".\MuteRepetitiveBrann.toc")) {
    throw "MuteRepetitiveBrann.toc was not found at repository root."
}

$repoRoot = Split-Path -Parent $PSCommandPath
$releaseDir = Get-FullPath -Path $OutputDir -BasePath $repoRoot

if (-not (Test-Path $releaseDir)) {
    New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
}

Push-Location $repoRoot
try {
    $invoked = Try-InvokeWslPackager -RepoRoot $repoRoot -ReleaseDir $releaseDir
    if (-not $invoked) {
        $invoked = Try-InvokeGitBashPackager -RepoRoot $repoRoot -ReleaseDir $releaseDir
    }

    if (-not $invoked) {
        throw @"
The official packager requires WSL or Git Bash on Windows.

Install one of the following, then run this command again from the repository root:
  powershell -ExecutionPolicy Bypass -File .\package.ps1

This wrapper downloads and runs the official BigWigs packager in dry-run mode, writing output to:
  $releaseDir
"@
    }

    Write-Host "`nPackaging complete. Inspect the output under $releaseDir" -ForegroundColor Green
}
finally {
    Pop-Location
}
