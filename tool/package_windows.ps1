# Packages the Windows release build for the machine's architecture (x64 or
# arm64, or the one given with -Arch):
#
#   <OutDir>\MockStudio-<version>-windows-<arch>.zip   the release build
#   <OutDir>\MockStudio[-arm64].msix                   the Microsoft Store package
#
# Run `flutter build windows --release` first. The zip is made before the
# MSIX because msix:create copies the VC runtime DLLs and icon files into the
# Release folder while it packs.
#
#   pwsh tool\package_windows.ps1 -OutDir dist
param(
    [string]$OutDir = 'dist',
    [ValidateSet('x64', 'arm64')]
    [string]$Arch
)
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
if (-not $Arch) {
    switch ($env:PROCESSOR_ARCHITECTURE) {
        'AMD64' { $Arch = 'x64' }
        'ARM64' { $Arch = 'arm64' }
        default { throw "unsupported PROCESSOR_ARCHITECTURE '$env:PROCESSOR_ARCHITECTURE' (AMD64 or ARM64)" }
    }
}
$versionLine = Select-String -Path pubspec.yaml -Pattern '^version:\s*(\S+)' | Select-Object -First 1
$version = ($versionLine.Matches[0].Groups[1].Value -split '\+')[0]
$release = "build\windows\$Arch\runner\Release"
if (-not (Test-Path "$release\mock_studio.exe")) {
    throw "$release\mock_studio.exe is missing - run: flutter build windows --release"
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$out = (Resolve-Path $OutDir).Path

$name = "MockStudio-$version-windows-$Arch"
$stage = Join-Path ([IO.Path]::GetTempPath()) "mockstudio-zip-$([guid]::NewGuid())"
try {
    New-Item -ItemType Directory -Path $stage | Out-Null
    Copy-Item -Recurse -Path $release -Destination (Join-Path $stage $name)
    $zip = Join-Path $out "$name.zip"
    if (Test-Path $zip) { Remove-Item $zip }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::CreateFromDirectory(
        (Join-Path $stage $name), $zip, [IO.Compression.CompressionLevel]::Optimal, $true)
} finally {
    Remove-Item -Recurse -Force $stage -ErrorAction SilentlyContinue
}
"Built $zip"

# msix:create assumes x64 on every host, so the architecture is explicit. The
# x64 package keeps the name msix_config gives it (MockStudio.msix).
$msixArgs = @('--store', '--build-windows', 'false', '--architecture', $Arch, '--output-path', $out)
if ($Arch -ne 'x64') { $msixArgs += @('--output-name', "MockStudio-$Arch") }
dart run msix:create @msixArgs
if ($LASTEXITCODE -ne 0) { throw "msix:create failed with exit code $LASTEXITCODE" }
