<#
  Stats-UI installer parts - the ONE implementation used by
    tools\split_exe.bat     (developer: split release\Stats-UI-Setup-X.Y.Z.exe)
    JOIN_AND_INSTALL.bat    (user: join the parts, verify, start Setup)

  You normally do NOT need parts: a GitHub *Release* accepts files up to 2 GB,
  and Stats-UI-Setup-X.Y.Z.exe is ~40-60 MB. Parts are only a fallback for
  uploading through the repository's "Add file" web page (25 MB per file).

  Split:  powershell -NoProfile -ExecutionPolicy Bypass -File tools\StatsUI-Parts.ps1 -Split release\Stats-UI-Setup-2.3.0.exe
          -> release\Stats-UI-Setup-2.3.0-parts\        (the parts + manifest + join tools)
          -> release\Stats-UI-Setup-2.3.0-parts.zip     (the same files zipped - built from an explicit
                                                         list, so a full Setup .exe can never end up in it)
  Join:   powershell -NoProfile -ExecutionPolicy Bypass -File StatsUI-Parts.ps1 -Join <folder with the parts>

  Format (v2): parts are named <file>.001, <file>.002, ... (zero-padded, joined
  strictly in that numeric order - never by a wildcard), and <file>.parts.txt
  lists every part with its size and SHA-256 plus the size and SHA-256 of the
  whole file. Joining checks every part first (so a damaged or missing part is
  named), writes to a temporary file, checks the result, and only then renames
  it to the installer name and starts it. Works in Windows PowerShell 5.1 and
  PowerShell 7.
#>
[CmdletBinding(DefaultParameterSetName = "Join")]
param(
  [Parameter(ParameterSetName = "Split", Mandatory = $true)][string]$Split,
  [Parameter(ParameterSetName = "Split")][int]$PartSizeMB = 24,
  [Parameter(ParameterSetName = "Split")][long]$PartSizeBytes = 0,
  [Parameter(ParameterSetName = "Split")][string]$OutDir = "",
  [Parameter(ParameterSetName = "Join")][string]$Join = "",
  [Parameter(ParameterSetName = "Join")][switch]$NoLaunch,
  [Parameter(ParameterSetName = "Join")][string]$OutFile = ""
)
$ErrorActionPreference = "Stop"
$FormatLine = "# Stats-UI parts manifest v2"

function Get-Sha256([string]$Path) {
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Fail([string]$Message) {
  Write-Host ""
  Write-Host "ERROR: $Message" -ForegroundColor Red
  exit 1
}

function Read-Manifest([string]$Folder) {
  $found = @(Get-ChildItem -LiteralPath $Folder -File -Filter "*.parts.txt" -ErrorAction SilentlyContinue)
  if ($found.Count -eq 0) {
    Fail ("No '*.parts.txt' file in $Folder. Download ALL files of the release (the .001, .002 ... files, " +
          "the .parts.txt file, StatsUI-Parts.ps1 and JOIN_AND_INSTALL.bat) into ONE folder and try again.")
  }
  if ($found.Count -gt 1) {
    Fail ("More than one '*.parts.txt' file in $Folder (" + (($found | ForEach-Object { $_.Name }) -join ", ") +
          "). Keep only the files of ONE version in this folder.")
  }
  $m = @{ Path = $found[0].FullName; Parts = @() }
  $lines = [System.IO.File]::ReadAllLines($found[0].FullName)
  if ($lines.Count -eq 0 -or $lines[0].Trim() -ne $FormatLine) { Fail "$($found[0].Name) is not a Stats-UI parts manifest." }
  foreach ($raw in $lines) {
    $line = $raw.Trim()
    if ($line -eq "" -or $line.StartsWith("#")) { continue }
    $kv = $line.Split("=", 2)
    if ($kv.Count -ne 2) { Fail "Damaged line in $($found[0].Name): $line" }
    switch ($kv[0]) {
      "file"   { $m.File = $kv[1] }
      "size"   { $m.Size = [long]$kv[1] }
      "sha256" { $m.Sha256 = $kv[1].ToLowerInvariant() }
      "count"  { $m.Count = [int]$kv[1] }
      "part"   {
        $f = $kv[1].Split(" ")
        if ($f.Count -ne 3) { Fail "Damaged part line in $($found[0].Name): $line" }
        $m.Parts += ,@{ Name = $f[0]; Size = [long]$f[1]; Sha256 = $f[2].ToLowerInvariant() }
      }
    }
  }
  if (-not $m.File -or -not $m.Sha256 -or $m.Count -lt 1 -or $m.Parts.Count -ne $m.Count) {
    Fail "$($found[0].Name) is incomplete - download it again."
  }
  if ($m.File -notmatch '^[A-Za-z0-9._-]+\.exe$') { Fail "Unexpected file name in manifest: $($m.File)" }
  for ($i = 0; $i -lt $m.Count; $i++) {
    $want = "{0}.{1:D3}" -f $m.File, ($i + 1)
    if ($m.Parts[$i].Name -ne $want) { Fail "Manifest lists parts out of order ($($m.Parts[$i].Name) where $want was expected)." }
  }
  return $m
}

function Join-Parts([string]$Folder, [string]$Target, [bool]$Quiet) {
  $Folder = (Resolve-Path -LiteralPath $Folder).Path
  $m = Read-Manifest $Folder
  if (-not $Target) { $Target = Join-Path $Folder $m.File }
  if (-not $Quiet) { Write-Host "Checking $($m.Count) part(s) of $($m.File) ..." }
  $problems = @()
  foreach ($p in $m.Parts) {
    $path = Join-Path $Folder $p.Name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $problems += "  missing:  $($p.Name)"; continue }
    $len = (Get-Item -LiteralPath $path).Length
    if ($len -ne $p.Size) { $problems += "  wrong size: $($p.Name) is $len bytes, should be $($p.Size)"; continue }
    if ((Get-Sha256 $path) -ne $p.Sha256) { $problems += "  damaged:  $($p.Name) (checksum differs)"; continue }
    if (-not $Quiet) { Write-Host "  ok  $($p.Name)" }
  }
  if ($problems.Count -gt 0) {
    Fail ("These parts are missing or damaged - download just these again (use 'Save link as', not 'Open'):`n" +
          ($problems -join "`n"))
  }
  $tmp = "$Target.joining"
  if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
  $out = [System.IO.File]::Open($tmp, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
  try {
    foreach ($p in $m.Parts) {               # strictly 001, 002, ... as listed and verified above
      $in = [System.IO.File]::OpenRead((Join-Path $Folder $p.Name))
      try { $in.CopyTo($out, 1048576) } finally { $in.Dispose() }
    }
  } finally { $out.Dispose() }
  $len = (Get-Item -LiteralPath $tmp).Length
  $got = Get-Sha256 $tmp
  if ($len -ne $m.Size -or $got -ne $m.Sha256) {
    Remove-Item -LiteralPath $tmp -Force
    Fail "The joined installer does not match (size $len/$($m.Size), SHA-256 $got). Nothing was started."
  }
  if (Test-Path -LiteralPath $Target) { Remove-Item -LiteralPath $Target -Force }
  Move-Item -LiteralPath $tmp -Destination $Target
  if (-not $Quiet) {
    Write-Host ""
    Write-Host "Joined and verified: $Target" -ForegroundColor Green
    Write-Host "SHA-256 $got"
  }
  return $Target
}

# ===================================================================== split
if ($PSCmdlet.ParameterSetName -eq "Split") {
  $src = (Resolve-Path -LiteralPath $Split).Path
  $name = Split-Path $src -Leaf
  if ($name -notmatch '^[A-Za-z0-9._-]+\.exe$') { Fail "Unexpected installer name: $name" }
  if ($PartSizeBytes -le 0) {
    if ($PartSizeMB -ge 25 -or $PartSizeMB -lt 1) { Fail "PartSizeMB must be 1..24 (GitHub web uploads must be under 25 MB)." }
    $PartSizeBytes = [long]$PartSizeMB * 1MB
  }
  $total = (Get-Item -LiteralPath $src).Length
  $count = [int][Math]::Ceiling($total / [double]$PartSizeBytes)
  if ($count -lt 1) { $count = 1 }
  if ($count -gt 999) { Fail "Too many parts ($count). Use a bigger -PartSizeMB." }
  if (-not $OutDir) { $OutDir = Join-Path (Split-Path $src -Parent) ($name -replace '\.exe$', '-parts') }
  if (Test-Path -LiteralPath $OutDir) { Remove-Item -LiteralPath $OutDir -Recurse -Force }  # no stray old files
  New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
  $OutDir = (Resolve-Path -LiteralPath $OutDir).Path

  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add($FormatLine)
  $lines.Add("file=$name")
  $lines.Add("size=$total")
  $lines.Add("sha256=" + (Get-Sha256 $src))
  $lines.Add("count=$count")
  $buffer = New-Object byte[] 1048576
  $in = [System.IO.File]::OpenRead($src)
  try {
    for ($i = 1; $i -le $count; $i++) {
      $partName = "{0}.{1:D3}" -f $name, $i
      $partPath = Join-Path $OutDir $partName
      $out = [System.IO.File]::Open($partPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write)
      try {
        $left = [long][Math]::Min($PartSizeBytes, $total - $in.Position)
        while ($left -gt 0) {
          $n = $in.Read($buffer, 0, [int][Math]::Min([long]$buffer.Length, $left))
          if ($n -le 0) { throw "Unexpected end of $name" }
          $out.Write($buffer, 0, $n)
          $left -= $n
        }
      } finally { $out.Dispose() }
      $lines.Add(("part={0} {1} {2}" -f $partName, (Get-Item -LiteralPath $partPath).Length, (Get-Sha256 $partPath)))
    }
  } finally { $in.Dispose() }
  [System.IO.File]::WriteAllLines((Join-Path $OutDir "$name.parts.txt"), $lines.ToArray(), (New-Object System.Text.ASCIIEncoding))

  Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $OutDir "StatsUI-Parts.ps1") -Force
  $joinBat = Join-Path (Split-Path $PSScriptRoot -Parent) "JOIN_AND_INSTALL.bat"
  if (-not (Test-Path -LiteralPath $joinBat)) { $joinBat = Join-Path $PSScriptRoot "JOIN_AND_INSTALL.bat" }
  Copy-Item -LiteralPath $joinBat -Destination $OutDir -Force

  # The ONLY files that belong to a parts set (explicit list - never a wildcard).
  $keep = @()
  for ($i = 1; $i -le $count; $i++) { $keep += ("{0}.{1:D3}" -f $name, $i) }
  $keep += @("$name.parts.txt", "StatsUI-Parts.ps1", "JOIN_AND_INSTALL.bat")
  foreach ($f in @(Get-ChildItem -LiteralPath $OutDir -Force)) {
    if ($keep -notcontains $f.Name) {
      Write-Host "Removing stray file from the parts folder: $($f.Name)" -ForegroundColor Yellow
      Remove-Item -LiteralPath $f.FullName -Recurse -Force
    }
  }
  if (Test-Path -LiteralPath (Join-Path $OutDir $name)) { Fail "A full $name is in the parts folder - not allowed." }

  # Self-check with the very same join code the user will run.
  $checkDir = Join-Path ([System.IO.Path]::GetTempPath()) ("statsui-join-check-" + [guid]::NewGuid())
  New-Item -ItemType Directory -Path $checkDir | Out-Null
  try {
    $joined = Join-Parts $OutDir (Join-Path $checkDir $name) $true
    if ((Get-Sha256 $joined) -ne (Get-Sha256 $src)) { Fail "Self-check failed: re-joined file differs from the original." }
  } finally { Remove-Item -LiteralPath $checkDir -Recurse -Force -ErrorAction SilentlyContinue }

  # Parts zip: one download for users, made from the explicit list above.
  $zipPath = Join-Path (Split-Path $OutDir -Parent) (($name -replace '\.exe$', '') + "-parts.zip")
  if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
  try {
    foreach ($k in $keep) {
      [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, (Join-Path $OutDir $k), $k,
        [System.IO.Compression.CompressionLevel]::Optimal)
    }
  } finally { $zip.Dispose() }

  Write-Host ""
  Write-Host "Split $name into $count part(s) in:" -ForegroundColor Green
  Write-Host "  $OutDir"
  Write-Host "  $zipPath  (the same files in one zip)"
  Write-Host "Self-check passed: joining them gives back the identical installer."
  Write-Host "Attach the -parts.zip to the Release (optional). Users unzip it and double-click JOIN_AND_INSTALL.bat."
  exit 0
}

# ====================================================================== join
if (-not $Join) { $Join = $PSScriptRoot }
$result = Join-Parts $Join $OutFile $false
if ($NoLaunch) { exit 0 }
Write-Host "Starting the installer ..."
Start-Process -FilePath $result
exit 0
