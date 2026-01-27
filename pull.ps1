param(
  [string]$GistUser  = $env:GIST_USER,
  [string]$GistId    = $env:GIST_ID,
  [string]$GistRev   = $env:GIST_REV,     # optional: pin revision
  [string]$ConfigDir = $env:CONFIG_DIR,   # optional override
  [switch]$NoBackup
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($GistUser)) { $GistUser = "ControlNet" }
if ([string]::IsNullOrWhiteSpace($GistId))   { $GistId   = "b10f23a707e3515e8fd215770e929b1a" }

function Timestamp { (Get-Date).ToString("yyyyMMdd-HHmmss") }

function Ensure-Dir([string]$Path) {
  if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Force -Path $Path | Out-Null }
}

function Unique-BackupPath([string]$BasePath) {
  if (-not (Test-Path $BasePath)) { return $BasePath }
  return "$BasePath-$PID"
}

function Download-File([string]$Url, [string]$OutFile) {
  $headers = @{ "Cache-Control" = "no-cache" }
  if ($PSVersionTable.PSVersion.Major -lt 6) {
    Invoke-WebRequest -Uri $Url -Headers $headers -UseBasicParsing -OutFile $OutFile
  } else {
    Invoke-WebRequest -Uri $Url -Headers $headers -OutFile $OutFile
  }
  if (-not (Test-Path $OutFile) -or ((Get-Item $OutFile).Length -le 0)) {
    throw "Download failed or empty: $Url"
  }
}

function Backup-And-Replace([string]$Src, [string]$Dst, [string]$Ts, [bool]$DoBackup) {
  Ensure-Dir (Split-Path -Parent $Dst)
  if ($DoBackup -and (Test-Path $Dst)) {
    $bak = Unique-BackupPath("$Dst.bak-$Ts")
    Copy-Item $Dst $bak -Force
  }
  Move-Item $Src $Dst -Force
}

function Rename-Json-IfExists([string]$JsonPath, [string]$Ts) {
  if (Test-Path $JsonPath) {
    $bak = Unique-BackupPath("$JsonPath.bak-$Ts")
    Move-Item $JsonPath $bak -Force
  }
}

# User-level config dir on Windows
if ([string]::IsNullOrWhiteSpace($ConfigDir)) {
  $ConfigDir = Join-Path $env:USERPROFILE ".config\opencode"
}
Ensure-Dir $ConfigDir

# Build URLs (pinned rev if provided; else "latest" raw endpoint)
if (-not [string]::IsNullOrWhiteSpace($GistRev)) {
  $UrlOpenCode = "https://gist.githubusercontent.com/$GistUser/$GistId/raw/$GistRev/opencode.jsonc"
  $UrlOmoc     = "https://gist.githubusercontent.com/$GistUser/$GistId/raw/$GistRev/oh-my-opencode.jsonc"
} else {
  $UrlOpenCode = "https://gist.github.com/$GistUser/$GistId/raw/opencode.jsonc"
  $UrlOmoc     = "https://gist.github.com/$GistUser/$GistId/raw/oh-my-opencode.jsonc"
}

$ts = Timestamp   # <<< FIX: no parentheses
$tmpDir = Join-Path $env:TEMP ("opencode-pull-" + [Guid]::NewGuid().ToString("N"))
Ensure-Dir $tmpDir

try {
  $tmpOpen = Join-Path $tmpDir "opencode.jsonc"
  $tmpOmoc = Join-Path $tmpDir "oh-my-opencode.jsonc"

  Write-Host "[1/3] Downloading:"
  Write-Host "      - $UrlOpenCode"
  Write-Host "      - $UrlOmoc"

  Download-File $UrlOpenCode $tmpOpen
  Download-File $UrlOmoc     $tmpOmoc

  Write-Host "[2/3] Installing to user-level dir: $ConfigDir"
  $doBackup = -not $NoBackup.IsPresent
  Backup-And-Replace $tmpOpen (Join-Path $ConfigDir "opencode.jsonc") $ts $doBackup
  Backup-And-Replace $tmpOmoc (Join-Path $ConfigDir "oh-my-opencode.jsonc") $ts $doBackup

  Write-Host "[3/3] Renaming legacy .json (if exists) so only .jsonc remains active"
  Rename-Json-IfExists (Join-Path $ConfigDir "opencode.json") $ts
  Rename-Json-IfExists (Join-Path $ConfigDir "oh-my-opencode.json") $ts

  Write-Host "Done. Timestamp: $ts"
  if ($doBackup) { Write-Host "Backups: *.bak-$ts" }
}
finally {
  if (Test-Path $tmpDir) { Remove-Item $tmpDir -Recurse -Force }
}