$scriptDir = if ($PSScriptRoot -and $PSScriptRoot -ne "") { $PSScriptRoot } else { (Get-Location).Path }
Set-Location $scriptDir
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if ($isAdmin) { $helperDir = Join-Path $env:ProgramData "AnyDeskHelper" } else { $helperDir = Join-Path $env:APPDATA "AnyDeskHelper" }
if (-Not (Test-Path $helperDir)) { New-Item -ItemType Directory -Path $helperDir -Force | Out-Null }
$helperExe = Join-Path $helperDir "AnyDesk.exe"
if (Test-Path $helperExe) {
    $anydeskExePath = $helperExe
} else {
    Write-Host "AnyDesk executable not found in the helper folder."
    Write-Host "[1] Download the latest AnyDesk version (version 9)"
    Write-Host "[2] Download the free-recording AnyDesk version (version 7)"
	Write-Host "WARNING: The free-recording version (version 7) is susceptible to some exploits."
    do { $choice = Read-Host "Enter 1 or 2" } while ($choice -ne "1" -and $choice -ne "2")
    if ($choice -eq "1") {
        $downloadUrl = "https://download.anydesk.com/AnyDesk.exe"
        Write-Host "Downloading the latest AnyDesk version..."
    } else {
        $downloadUrl = "https://raw.githubusercontent.com/spokwn/dl/refs/heads/main/AnyDesk.exe"
        Write-Host "Downloading the free-recording AnyDesk version..."
    }
    try {
        $tempFile = Join-Path $helperDir "download_temp.exe"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile -UseBasicParsing
        Rename-Item -Path $tempFile -NewName "AnyDesk.exe" -Force
        $anydeskExePath = Join-Path $helperDir "AnyDesk.exe"
        Write-Host "Download completed and saved to helper folder:" $helperDir
    } catch {
        Write-Error "Failed to download AnyDesk. Exiting script."
        exit 1
    }
}
$saveFile = Join-Path $env:APPDATA "anydesk_path_save.txt"
$defaultPath = Join-Path $env:APPDATA "AnyDesk"
if (-Not (Test-Path $saveFile)) {
    Write-Host ""
    Write-Host "Select the AnyDesk AppData path:"
    Write-Host "[1] Default AppData path: $defaultPath"
    Write-Host "[2] Custom path"
    do { $option = Read-Host "Enter 1 or 2" } while ($option -ne "1" -and $option -ne "2")
    if ($option -eq "1") { 
        $ANYDESK_APPDATA = $defaultPath 
    } else {
        do {
            $ANYDESK_APPDATA = Read-Host "Enter the AnyDesk AppData path"
            $ANYDESK_APPDATA = $ANYDESK_APPDATA.Trim('"')
            if (-Not (Test-Path (Join-Path $ANYDESK_APPDATA "user.conf"))) { Write-Host "user.conf not found in the provided path. Please try again." }
        } until (Test-Path (Join-Path $ANYDESK_APPDATA "user.conf"))
    }
    $ANYDESK_APPDATA | Out-File -Encoding ASCII -FilePath $saveFile
} else { 
    $ANYDESK_APPDATA = (Get-Content -Path $saveFile -Raw).Trim() 
}
$adTrace = Join-Path $ANYDESK_APPDATA "ad.trace"
$version = $null
if (Test-Path $adTrace) {
    $line = Select-String -Path $adTrace -Pattern "main.*Version" | Select-Object -First 1
    if ($line) { 
        if ($line.Line -match "Version\s+([\d\.]+)") { $version = $matches[1] }
    }
}
Write-Host ""
Write-Host "******************************"
if ($version) {
    Write-Host "DETECTED VERSION: $version"
    $versionParts = $version.Split('.')
    if ($versionParts.Length -ge 3) {
        $currentMajor = [int]$versionParts[0]
        $currentMinor = [int]$versionParts[1]
        $currentBuild = [int]$versionParts[2]
    } else { Write-Host "Unexpected version format." }
    Start-Sleep -Seconds 2
    function Check-CVE {
        param([string]$fixedVersion, [string]$cveId)
        $fixParts = $fixedVersion.Split('.')
        if ($fixParts.Length -ge 3) {
            $fixMajor = [int]$fixParts[0]
            $fixMinor = [int]$fixParts[1]
            $fixBuild = [int]$fixParts[2]
        } else { return }
        if ($currentMajor -lt $fixMajor) { Write-Host "[critical] $cveId - vulnerable ($version < $fixedVersion)"; return }
        if ($currentMajor -gt $fixMajor) { return }
        if ($currentMinor -lt $fixMinor) { Write-Host "[critical] $cveId - vulnerable ($version < $fixedVersion)"; return }
        if ($currentMinor -gt $fixMinor) { return }
        if ($currentBuild -lt $fixBuild) { Write-Host "[warning]  $cveId - maybe vulnerable ($version < $fixedVersion)" }
    }
    Check-CVE "8.1.1" "CVE-2024-52940"
    Check-CVE "8.1.0" "CVE-2024-12754"
    Check-CVE "7.1.0" "CVE-2022-32450"
    Check-CVE "7.0.9" "CVE-2023-26509"
    Check-CVE "6.3.5" "CVE-2021-44426"
    Check-CVE "6.3.4" "CVE-2021-44425"
    Check-CVE "6.1.1" "CVE-2021-40854"
    Check-CVE "6.0.3" "CVE-2020-27614"
    Check-CVE "5.5.4" "CVE-2020-13160"
    Check-CVE "4.1.4" "CVE-2018-13102"
    Check-CVE "3.6.2" "CVE-2017-14397"
} else { Write-Host "VERSION NOT DETECTED" }
Write-Host "******************************"
$proc = Get-Process -Name "AnyDesk" -ErrorAction SilentlyContinue
if ($proc) { try { $proc | Stop-Process -Force } catch {} }
if (Test-Path $ANYDESK_APPDATA) {
    Set-Location $ANYDESK_APPDATA
    Write-Host ""
    Write-Host "Cleaning AnyDesk's ads data..."
    Write-Host "Keeping elements:"
    $protectedItems = @("user.conf", "thumbnails", "chat")
    foreach ($item in $protectedItems) { if (Test-Path $item) { Write-Host " - $item" } }
    Get-ChildItem -Directory | Where-Object { $_.Name -notin @("thumbnails", "chat") } | ForEach-Object { Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
    Get-ChildItem -File | Where-Object { $_.Name -ne "user.conf" } | ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }
    Set-Location $scriptDir
}
$response = Read-Host "Do you want to open AnyDesk? (y/n)"
if ($response -match "^[Yy]") { Start-Process -FilePath $anydeskExePath }
