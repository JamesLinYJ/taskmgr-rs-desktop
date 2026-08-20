# +-------------------------------------------------------------------------
#
#   taskmgr-rs - Windows 发布包构建
#
#   文件:       scripts/Build-WindowsPackages.ps1
#
#   日期:       2026年08月20日
#   环境:       Windows x64/ARM64；PowerShell 7；Inno Setup 6
#   作者:       JamesLinYJ
#   协助:       OpenAI Codex:gpt-5.6-sol
#   参考标准:   Flutter Windows bundle 布局；Inno Setup 6；ZIP
# --------------------------------------------------------------------------

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $Bundle,

    [Parameter(Mandatory = $true)]
    [string] $Helper,

    [ValidateSet('x64', 'arm64')]
    [string] $Architecture = 'x64',

    [string] $Output = 'dist',

    [string] $Version = '0.3.0'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$bundlePath = (Resolve-Path -LiteralPath $Bundle).Path
$helperPath = (Resolve-Path -LiteralPath $Helper).Path
$outputPath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Output))

if (-not (Test-Path -LiteralPath (Join-Path $bundlePath 'taskmgr_rs.exe') -PathType Leaf)) {
    throw "Invalid Flutter Windows bundle: $bundlePath"
}
if (-not (Test-Path -LiteralPath $helperPath -PathType Leaf)) {
    throw "taskmgr-helper.exe is missing: $helperPath"
}

& (Join-Path $repoRoot 'scripts/Audit-WindowsBundle.ps1') -Bundle $bundlePath
New-Item -ItemType Directory -Force -Path $outputPath | Out-Null

$stageRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("taskmgr-rs-package-" + [guid]::NewGuid())
$portableName = "taskmgr-rs-$Version-windows-$Architecture"
$portableRoot = Join-Path $stageRoot $portableName

try {
    New-Item -ItemType Directory -Force -Path $portableRoot | Out-Null
    Copy-Item -Path (Join-Path $bundlePath '*') -Destination $portableRoot -Recurse -Force
    Copy-Item -LiteralPath $helperPath -Destination (Join-Path $portableRoot 'taskmgr-helper.exe') -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot 'LICENSE') -Destination (Join-Path $portableRoot 'LICENSE') -Force

    $zipPath = Join-Path $outputPath "$portableName.zip"
    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }
    Compress-Archive -LiteralPath $portableRoot -DestinationPath $zipPath -CompressionLevel Optimal
    $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        $entries = @($zip.Entries | ForEach-Object { $_.FullName })
        if (@($entries | Where-Object { $_ -like '*/taskmgr_native.dll' }).Count -ne 1) {
            throw 'Portable ZIP must contain exactly one taskmgr_native.dll'
        }
        if (@($entries | Where-Object { $_ -like '*/taskmgr-helper.exe' }).Count -ne 1) {
            throw 'Portable ZIP must contain taskmgr-helper.exe'
        }
    }
    finally {
        $zip.Dispose()
    }

    $isccCommand = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    $isccPath = if ($null -eq $isccCommand) { $null } else { $isccCommand.Source }
    if ($null -eq $isccPath) {
        $defaultIscc = Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'
        if (Test-Path -LiteralPath $defaultIscc -PathType Leaf) {
            $isccPath = $defaultIscc
        }
    }
    if ($null -ne $isccPath) {
        $innoArch = if ($Architecture -eq 'arm64') {
            'arm64'
        }
        else {
            'x64compatible and not arm64'
        }
        $arguments = @(
            "/DBundleDir=$bundlePath",
            "/DHelperPath=$helperPath",
            "/DOutputDir=$outputPath",
            "/DMyVersion=$Version",
            "/DMyArch=$innoArch",
            "/DMyArchLabel=$Architecture",
            "/DLicensePath=$(Join-Path $repoRoot 'LICENSE')",
            "/DSetupIconPath=$(Join-Path $repoRoot 'flutter_app/windows/runner/resources/app_icon.ico')",
            (Join-Path $repoRoot 'packaging/windows/taskmgr-rs.iss')
        )
        & $isccPath @arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Inno Setup failed with exit code $LASTEXITCODE"
        }
    }
    else {
        Write-Warning 'ISCC.exe unavailable; Inno Setup generation skipped'
    }

    $artifacts = Get-ChildItem -LiteralPath $outputPath -File | Where-Object {
        $_.Name -like "taskmgr-rs-$Version-windows-$Architecture*"
    } | Sort-Object Name
    $checksumPath = Join-Path $outputPath "SHA256SUMS-windows-$Architecture"
    $checksums = foreach ($artifact in $artifacts) {
        $hash = (Get-FileHash -LiteralPath $artifact.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        "$hash  $($artifact.Name)"
    }
    Set-Content -LiteralPath $checksumPath -Value $checksums -Encoding utf8NoBOM
    Write-Host "Windows packages written to $outputPath"
}
finally {
    if ($stageRoot.StartsWith([System.IO.Path]::GetTempPath(), [System.StringComparison]::OrdinalIgnoreCase) -and
        (Test-Path -LiteralPath $stageRoot)) {
        Remove-Item -LiteralPath $stageRoot -Recurse -Force
    }
}
