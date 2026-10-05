param(
    [Parameter(Mandatory = $true)]
    [string]$OrangeFoxImage,
    [string]$BaseBoot = 'D:\joeyzhu\Desktop\pak\firmware\boot_sukisu.img',
    [string]$Output = '.\OrangeFox-pipa-A17-SukiSU.img',
    [string]$MagiskBoot = 'D:\joeyzhu\Downloads\MIO-KITCHEN-4.1.9-v2-win\bin\Windows\AMD64\magiskboot.exe'
)

$ErrorActionPreference = 'Stop'
foreach ($path in @($OrangeFoxImage, $BaseBoot, $MagiskBoot)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing required file: $path" }
}

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("pipa-orangefox-" + [guid]::NewGuid())
$Output = [System.IO.Path]::GetFullPath($Output)
New-Item -ItemType Directory -Path $work | Out-Null
try {
    $foxDir = Join-Path $work 'orangefox'
    $baseDir = Join-Path $work 'base'
    New-Item -ItemType Directory -Path $foxDir, $baseDir | Out-Null

    Push-Location $foxDir
    & $MagiskBoot unpack (Resolve-Path -LiteralPath $OrangeFoxImage)
    if (-not (Test-Path 'ramdisk.cpio')) { throw 'OrangeFox image has no boot ramdisk.' }
    $orangeFoxRamdisk = Join-Path $work 'orangefox-ramdisk.cpio'
    Move-Item 'ramdisk.cpio' $orangeFoxRamdisk
    Pop-Location

    Push-Location $baseDir
    & $MagiskBoot unpack (Resolve-Path -LiteralPath $BaseBoot)
    if (-not (Test-Path 'ramdisk.cpio')) { throw 'The stable SukiSU boot image has no ramdisk.' }
    Copy-Item $orangeFoxRamdisk 'ramdisk.cpio' -Force
    & $MagiskBoot repack (Resolve-Path -LiteralPath $BaseBoot) $Output
    Pop-Location

    if (-not (Test-Path $Output)) { throw 'magiskboot did not generate the requested image.' }
    Write-Host "Created $Output"
}
finally {
    if ((Get-Location).Path -like "$work*") { Pop-Location }
    Remove-Item -LiteralPath $work -Recurse -Force
}
