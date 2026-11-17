# Corriger-Version-Atrium.ps1
# Run on the original owner PC, not a distributed portable copy.
# Fixes a version format that System.Version cannot compare when HHmmss > 65535.
# A backup is always created. Restart Atrium after applying.
param([Parameter(Mandatory=$true)][string]$HomeServer)
$ErrorActionPreference = 'Stop'
$path = (Resolve-Path -LiteralPath $HomeServer -ErrorAction Stop).Path
if ([IO.Path]::GetFileName($path) -ne 'home-server.ps1') { throw 'Select the original mpv/home-server.ps1.' }
$dir = Split-Path -Parent $path
if (Test-Path -LiteralPath (Join-Path $dir 'update.json')) {
    throw 'This is a portable client, not the original Atrium owner/server.'
}
$utf8 = New-Object System.Text.UTF8Encoding($false)
$src = [IO.File]::ReadAllText($path, $utf8)
$from = @'
$version = $now.ToString('yyyy.M.d.') + [string]([int]$now.ToString('HHmmss'))
'@
$to = @'
$version = $now.ToString('yyyy.M.d.') + [string]([int]$now.ToString('HHmm'))
'@
if ($src.Contains($to)) {
    Write-Host 'The release version format is already compatible.' -ForegroundColor Green
    exit 0
}
$parts = $src.Split(@($from), [StringSplitOptions]::None)
if ($parts.Length -ne 2) { throw 'The expected build-version code was not found exactly once. No changes.' }
if ($src -notmatch 'function Build-Update') { throw 'Not a compatible Atrium Windows server. No changes.' }
$backup = $path + '.pre-asian-version-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.bak'
Copy-Item -LiteralPath $path -Destination $backup -ErrorAction Stop
[IO.File]::WriteAllText($path, $src.Replace($from, $to), $utf8)
Write-Host ('Fixed release version generation. Backup: ' + $backup) -ForegroundColor Green
Write-Host 'Restart the original Atrium server so this fix takes effect BEFORE publishing.'
