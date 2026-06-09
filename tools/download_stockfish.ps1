param(
  [string]$ReleaseTag,
  [string]$AssetName,
  [string]$DestinationPath
)

$ErrorActionPreference = "Stop"

$ReleaseTag = if ([string]::IsNullOrWhiteSpace($ReleaseTag)) {
  if ([string]::IsNullOrWhiteSpace($env:CHESSGPT_STOCKFISH_RELEASE_TAG)) {
    "sf_18"
  } else {
    $env:CHESSGPT_STOCKFISH_RELEASE_TAG
  }
} else {
  $ReleaseTag
}

$AssetName = if ([string]::IsNullOrWhiteSpace($AssetName)) {
  if ([string]::IsNullOrWhiteSpace($env:CHESSGPT_STOCKFISH_ASSET_NAME)) {
    "stockfish-windows-x86-64.zip"
  } else {
    $env:CHESSGPT_STOCKFISH_ASSET_NAME
  }
} else {
  $AssetName
}

$DestinationPath = if ([string]::IsNullOrWhiteSpace($DestinationPath)) {
  if ([string]::IsNullOrWhiteSpace($env:CHESSGPT_STOCKFISH_DESTINATION_PATH)) {
    "third_party\\stockfish\\windows\\stockfish.exe"
  } else {
    $env:CHESSGPT_STOCKFISH_DESTINATION_PATH
  }
} else {
  $DestinationPath
}

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$destination = Join-Path $projectRoot $DestinationPath
$destinationDir = Split-Path -Parent $destination
$downloadUrl = "https://github.com/official-stockfish/Stockfish/releases/download/$ReleaseTag/$AssetName"
$zipPath = Join-Path $env:TEMP "stockfish_download.zip"
$extractDir = Join-Path $env:TEMP "stockfish_extract_$([guid]::NewGuid().ToString('N'))"

New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null
if (Test-Path $extractDir) {
  Remove-Item $extractDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $extractDir | Out-Null

Write-Host "Downloading Stockfish from $downloadUrl"
Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath

Write-Host "Extracting archive to $extractDir"
Expand-Archive -LiteralPath $zipPath -DestinationPath $extractDir -Force

$engine = Get-ChildItem -Path $extractDir -Recurse -File |
  Where-Object { $_.Extension -eq ".exe" -and $_.Name -like "stockfish*.exe" } |
  Select-Object -First 1

if (-not $engine) {
  throw "Could not find stockfish.exe inside $AssetName"
}

Copy-Item -LiteralPath $engine.FullName -Destination $destination -Force

$copying = Get-ChildItem -Path $extractDir -Recurse -File |
  Where-Object { $_.Name -match "^(copying|license)(\\..+)?$" } |
  Select-Object -First 1
if ($copying) {
  Copy-Item -LiteralPath $copying.FullName `
    -Destination (Join-Path $destinationDir "COPYING.txt") `
    -Force
}

$readme = Get-ChildItem -Path $extractDir -Recurse -File |
  Where-Object { $_.BaseName -eq "README" } |
  Select-Object -First 1
if ($readme) {
  Copy-Item -LiteralPath $readme.FullName `
    -Destination (Join-Path $destinationDir "README.stockfish.txt") `
    -Force
}

Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Saved Stockfish to $destination"
