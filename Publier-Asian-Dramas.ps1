# Publish-Signed-Asian-Dramas.ps1
# Publish a signed Atrium Windows update from the original owner PC.
# Requires Git for Windows, GitHub CLI (gh) with push access, and the
# installed, running localhost:18731 Atrium with Asian Dramas enabled.
# No Stremio keys or private signing keys are copied to GitHub.
param([string]$Repository='Jeysxn9321/atrium-updates',[string]$BaseUrl='http://localhost:18731')
$ErrorActionPreference='Stop'
$BaseUrl=$BaseUrl.TrimEnd('/')
# Public RSA verification key already embedded in the existing portable clients.
$PublicKey='<RSAKeyValue><Modulus>0ReOBnbCm0AcZPAVW9JOcvLaX5r3swvbOtm16tG3+RrZ8PH6hfa2jAY4DxNgH+48F8zLupxDh/RAWwDSu7yfpkguiz72UIgWg58RjNDIwmSOT+5PiRLcpVvVD73tJGxP+TIEj5M99ZYPVqTueVcGwvX3nAmL95DgWxHEfHPSDVKXE7xnYJey1124aAPRzQQtLN6xmuKo0RSc8UILCg57BYvJuY1NxVFNPa9tGhCHbHICjbs1xVdvQgB7bC9aLj1yBHwyfAGzJoitD4MpmtO9T2HhyT7Az6a29S/NozESHfEsu4DAKHr2EmyrLVr5c+reQiEaS0yMUO2SJMMlFB1V9Q==</Modulus><Exponent>AQAB</Exponent></RSAKeyValue>'

function Assert-SignedManifest($m) {
    if ([string]$m.version -notmatch '^\d+(\.\d+){1,3}$' -or
        [string]$m.file -notmatch '^atrium-update-[\d.]+\.zip$' -or
        [string]$m.sha256 -notmatch '^[a-f0-9]{64}$' -or
        [string]$m.size -notmatch '^\d{1,9}$' -or
        -not $m.sig) { throw 'Invalid signed update manifest.' }
    $msg=[Text.Encoding]::UTF8.GetBytes(('atrium-update|'+[string]$m.version+'|'+[string]$m.file+'|'+[string]$m.sha256+'|'+[string]$m.size))
    $rsa=[Security.Cryptography.RSA]::Create()
    try {
        $rsa.FromXmlString($PublicKey)
        if (-not $rsa.VerifyData($msg,[Convert]::FromBase64String([string]$m.sig),[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)) {
            throw 'Signature does not match the public key embedded in existing Atrium clients.'
        }
    } finally { $rsa.Dispose() }
}
foreach($cmd in @('git','gh')) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) { throw "Missing $cmd; install Git for Windows and GitHub CLI." }
}
& gh auth status 1>$null 2>$null
if($LASTEXITCODE -ne 0) { throw 'Run gh auth login first.' }

$source="https://raw.githubusercontent.com/$Repository/main"
$previous=Invoke-RestMethod ($source+'/latest.json?t='+[DateTime]::UtcNow.Ticks)
Assert-SignedManifest $previous

Write-Host "Checking running Atrium at $BaseUrl..."
try { $page=(Invoke-WebRequest -Uri ($BaseUrl+'/') -UseBasicParsing -TimeoutSec 12).Content }
catch { throw 'Start Atrium Windows on localhost:18731 before publishing.' }
if($page -notmatch 'Asian Dramas' -or $page -notmatch 'data-tab="asian"') {
    throw 'Asian Dramas is not installed in this local Atrium. No update published.'
}
$match=[regex]::Match($page,"const\s+TOKEN\s*=\s*'([a-f0-9]{32})'")
if(-not $match.Success) { throw 'Unable to read the local Atrium session token.' }
$headers=@{ 'X-Home'=$match.Groups[1].Value }
$versionInfo=Invoke-RestMethod -Uri ($BaseUrl+'/api/version') -Headers $headers -TimeoutSec 12
if($versionInfo.copy) { throw 'This is a portable copy, not the original signing PC.' }

Write-Host 'Building a signed release on the original PC...'
$release=Invoke-RestMethod -Uri ($BaseUrl+'/api/update/build') -Method Post -Headers $headers -ContentType 'text/plain; charset=utf-8' -Body 'Asian Dramas: Korean and Japanese series catalogues' -TimeoutSec 180
if(-not $release.ok) { throw ('Build failed: '+[string]$release.error) }
$folder=[string]$release.folder
$zipPath=Join-Path $folder ([string]$release.file)
$manifestPath=Join-Path $folder 'latest.json'
if(-not (Test-Path -LiteralPath $zipPath) -or -not (Test-Path -LiteralPath $manifestPath)) { throw 'Release files missing.' }
$manifest=Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
Assert-SignedManifest $manifest
try { [void][version]([string]$manifest.version) }
catch { throw 'The release revision exceeds Windows System.Version limits. Run Corriger-Version-Atrium.ps1 on the original mpv/home-server.ps1, restart Atrium, and publish again.' }
if([string]$manifest.version -ne [string]$release.version) { throw 'Version mismatch.' }
if([version]$manifest.version -le [version]$previous.version) { throw 'Version is not newer than the published release.' }
if([long](Get-Item -LiteralPath $zipPath).Length -ne [long]$manifest.size) { throw 'ZIP size mismatch.' }
if((Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne [string]$manifest.sha256) { throw 'ZIP SHA256 mismatch.' }
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$archive=[IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    $entries=@($archive.Entries | ForEach-Object { $_.FullName })
    if($entries -notcontains 'mpv/home.html' -or $entries -notcontains 'mpv/home-server.ps1') { throw 'Unexpected update archive layout.' }
    if(@($entries | Where-Object { $_ -match '(^|/)\.\.' -or $_ -match '(^|/)(?:stremio-key|tmdb-key|update-signing-key)\.txt$' }).Count) {
        throw 'A private key or unsafe path was found in the package.'
    }
} finally { $archive.Dispose() }

$temp=Join-Path $env:TEMP ('atrium-publish-'+[guid]::NewGuid().ToString('N'))
try {
    & gh repo clone $Repository $temp -- -q
    if($LASTEXITCODE -ne 0) { throw 'Cannot clone the updates repository.' }
    $current=Get-Content -LiteralPath (Join-Path $temp 'latest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if([string]$current.version -ne [string]$previous.version) { throw 'Another update was just published; stopping.' }
    Copy-Item -LiteralPath $zipPath -Destination (Join-Path $temp $manifest.file) -Force
    Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $temp 'latest.json') -Force
    & git -C $temp add -- $manifest.file latest.json
    & git -C $temp commit -m ('release: signed Atrium '+$manifest.version+' with Asian Dramas')
    if($LASTEXITCODE -ne 0) { throw 'Git commit failed. Configure your git name/email.' }
    & git -C $temp push origin HEAD:main
    if($LASTEXITCODE -ne 0) { throw 'Git push failed; update not published.' }
    Write-Host ('SIGNED UPDATE PUBLISHED: '+$manifest.version) -ForegroundColor Green
} finally {
    if(Test-Path -LiteralPath $temp) {
        Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
    }
}
