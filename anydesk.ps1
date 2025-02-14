$scriptDir = if ($PSScriptRoot -and $PSScriptRoot -ne "") { $PSScriptRoot } else { (Get-Location).Path }
Set-Location $scriptDir
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if ($isAdmin) { $helperDir = Join-Path $env:ProgramData "AnyDeskHelper" } else { $helperDir = Join-Path $env:APPDATA "AnyDeskHelper" }
if (-Not (Test-Path $helperDir)) { New-Item -ItemType Directory -Path $helperDir -Force | Out-Null }
$helperExe = Join-Path $helperDir "AnyDesk.exe"
if (Test-Path $helperExe) {
    $anydeskExePath = $helperExe
} else {
    Write-Host "`n[ERROR] AnyDesk executable not found in the helper folder." -ForegroundColor DarkRed
    Write-Host "`n[INFO] Optional: provide a custom path containing 'AnyDesk.exe' (it will be moved)." -ForegroundColor Blue
    $customPath = Read-Host "Enter custom path (or press Enter to download the latest version)"
    if ($customPath -and (Test-Path (Join-Path $customPath "AnyDesk.exe"))) {
        Write-Host "`n[SUCCESS] Found 'AnyDesk.exe' in the custom path. Moving it to the helper folder..." -ForegroundColor DarkGreen
        Move-Item -Path (Join-Path $customPath "AnyDesk.exe") -Destination $helperExe -Force
        $anydeskExePath = $helperExe
        Write-Host "[SUCCESS] 'AnyDesk.exe' has been moved to: $helperDir" -ForegroundColor DarkGreen
    } else {
        if ($customPath) { Write-Host "`n[WARN] 'AnyDesk.exe' not found in the provided path. Proceeding to download." -ForegroundColor DarkYellow }
        $downloadUrl = "https://download.anydesk.com/AnyDesk.exe"
        Write-Host "`n[INFO] Downloading the latest AnyDesk version..." -ForegroundColor Blue
        try {
            $tempFile = Join-Path $helperDir "download_temp.exe"
            Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile -UseBasicParsing
            Rename-Item -Path $tempFile -NewName "AnyDesk.exe" -Force
            $anydeskExePath = Join-Path $helperDir "AnyDesk.exe"
            Write-Host "[SUCCESS] Download completed and saved to: $helperDir" -ForegroundColor DarkGreen
        } catch {
            Write-Error "Failed to download AnyDesk. Exiting script."
            exit 1
        }
    }
}
$saveFile = Join-Path $env:APPDATA "anydesk_path_save.txt"
$defaultPath = Join-Path $env:APPDATA "AnyDesk"
if (-Not (Test-Path $saveFile)) {
    Write-Host "`n═══════════════════════════════════"
    Write-Host "Select the AnyDesk AppData path:" -ForegroundColor Blue
    Write-Host "[1] Default AppData path: $defaultPath" -ForegroundColor DarkYellow
    Write-Host "[2] Custom path" -ForegroundColor DarkYellow
    Write-Host "═══════════════════════════════════`n"
    do { $option = Read-Host "Enter 1 or 2" } until ($option -eq "1" -or $option -eq "2")
    if ($option -eq "1") { 
        $ANYDESK_APPDATA = $defaultPath 
    } else {
        do {
            $ANYDESK_APPDATA = Read-Host "Enter the AnyDesk AppData path (ensure 'user.conf' exists)"
            $ANYDESK_APPDATA = $ANYDESK_APPDATA.Trim('"')
            if (-Not (Test-Path (Join-Path $ANYDESK_APPDATA "user.conf"))) { Write-Host "[ERROR] 'user.conf' not found. Please try again." -ForegroundColor DarkRed }
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
function Write-BoxLine {
    param(
        [string]$text,
        [string]$color = "DarkGreen",
        [int]$boxWidth = 72
    )
    Write-Host -NoNewline "║ " -ForegroundColor DarkMagenta
    Write-Host -NoNewline $text -ForegroundColor $color
    $padding = $boxWidth - $text.Length - 3
    if ($padding -lt 0) { $padding = 1 }
    Write-Host (" " * $padding + "║") -ForegroundColor DarkMagenta
}
Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor DarkMagenta
if ($version) {
    Write-BoxLine "DETECTED VERSION: $version" "DarkGreen"
    $versionParts = $version.Split('.')
    if ($versionParts.Length -ge 3) {
        $currentMajor = [int]$versionParts[0]
        $currentMinor = [int]$versionParts[1]
        $currentBuild = [int]$versionParts[2]
    } else {
        Write-BoxLine "Unexpected version format." "DarkRed"
    }
    Start-Sleep -Seconds 2
    function Check-CVE {
        param([string]$fixedVersion, [string]$cveId)
        $fixParts = $fixedVersion.Split('.')
        if ($fixParts.Length -ge 3) {
            $fixMajor = [int]$fixParts[0]
            $fixMinor = [int]$fixParts[1]
            $fixBuild = [int]$fixParts[2]
        } else { return }
        if ($currentMajor -lt $fixMajor -or ($currentMajor -eq $fixMajor -and $currentMinor -lt $fixMinor)) {
            Write-BoxLine "[CRITICAL] $cveId - vulnerable ($version < $fixedVersion)" "DarkRed"
            return
        }
        if ($currentMajor -eq $fixMajor -and $currentMinor -eq $fixMinor -and $currentBuild -lt $fixBuild) {
            Write-BoxLine "[WARNING] $cveId - maybe vulnerable ($version < $fixedVersion)" "DarkYellow"
        }
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
} else {
    Write-BoxLine "VERSION NOT DETECTED" "DarkRed"
}
Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor DarkMagenta
$proc = Get-Process -Name "AnyDesk" -ErrorAction SilentlyContinue
if ($proc) { try { $proc | Stop-Process -Force } catch {} }
if (Test-Path $ANYDESK_APPDATA) {
    Set-Location $ANYDESK_APPDATA
    Write-Host "`n[INFO] Cleaning AnyDesk's ads data..." -ForegroundColor Blue
    Write-Host "`nKept elements:" -ForegroundColor DarkCyan
    $protectedItems = @("user.conf", "thumbnails", "chat")
    foreach ($item in $protectedItems) { if (Test-Path $item) { Write-Host "  ├─ $item" -ForegroundColor DarkGreen } }
    Get-ChildItem -Directory | Where-Object { $_.Name -notin @("thumbnails", "chat") } | ForEach-Object { Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
    Get-ChildItem -File | Where-Object { $_.Name -ne "user.conf" } | ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }
    Set-Location $scriptDir
}
$response = Read-Host "`nDo you want to open AnyDesk? (y/n)"
if ($response -match "^[Yy]") { Start-Process -FilePath $anydeskExePath }
