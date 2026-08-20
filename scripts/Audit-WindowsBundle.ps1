# +-------------------------------------------------------------------------
#
#   taskmgr-rs - Windows Flutter bundle 内容审计
#
#   文件:       scripts/Audit-WindowsBundle.ps1
#
#   日期:       2026年08月20日
#   环境:       Windows x64/ARM64；PowerShell 7；Flutter 3.44.7
#   作者:       JamesLinYJ
#   协助:       OpenAI Codex:gpt-5.6-sol
#   参考标准:   Flutter Windows bundle 布局；项目单一 Rust cdylib 契约
# --------------------------------------------------------------------------

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $Bundle
)

$ErrorActionPreference = 'Stop'
$resolvedBundle = (Resolve-Path -LiteralPath $Bundle).Path
$executable = Join-Path $resolvedBundle 'taskmgr_rs.exe'
$flutterEngine = Join-Path $resolvedBundle 'flutter_windows.dll'
if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
    throw "taskmgr_rs.exe is missing from $resolvedBundle"
}
if (-not (Test-Path -LiteralPath $flutterEngine -PathType Leaf)) {
    throw "flutter_windows.dll is missing from $resolvedBundle"
}
$trayPlugin = Join-Path $resolvedBundle 'tray_manager_plugin.dll'
if (-not (Test-Path -LiteralPath $trayPlugin -PathType Leaf)) {
    throw "tray_manager_plugin.dll is missing from $resolvedBundle"
}
foreach ($edge in @(16, 32)) {
    $defaultApplicationIcon = Join-Path $resolvedBundle "data\flutter_assets\assets\icons\default-process-$edge.png"
    if (-not (Test-Path -LiteralPath $defaultApplicationIcon -PathType Leaf)) {
        throw "Classic ${edge}px default application icon is missing from the bundle"
    }
}
$trayAssetDirectory = Join-Path $resolvedBundle 'data\flutter_assets\assets\tray'
$pngTrayAssets = @(Get-ChildItem -LiteralPath $trayAssetDirectory -File -Filter 'cpu-usage-level-*.png')
$icoTrayAssets = @(Get-ChildItem -LiteralPath $trayAssetDirectory -File -Filter 'cpu-usage-level-*.ico')
if ($pngTrayAssets.Count -ne 12 -or $icoTrayAssets.Count -ne 12) {
    throw 'The bundle must contain all 12 classic CPU tray levels as PNG and ICO'
}

$nativeLibraries = @(
    Get-ChildItem -LiteralPath $resolvedBundle -Recurse -File -Filter 'taskmgr*.dll'
)
if ($nativeLibraries.Count -ne 1) {
    throw "Expected exactly one taskmgr Rust DLL, found $($nativeLibraries.Count)"
}
if ($nativeLibraries[0].Name -cne 'taskmgr_native.dll') {
    throw "Unexpected Rust DLL: $($nativeLibraries[0].FullName)"
}

Write-Host "Bundle audit passed: $resolvedBundle"
Write-Host "Rust library: $($nativeLibraries[0].FullName)"
