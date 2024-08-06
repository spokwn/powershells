# By semental and espouken (90% espouken LMAO)

function Get-OldestConnectTime {
    $oldestLogon = Get-CimInstance -ClassName Win32_LogonSession | 
        Where-Object {$_.LogonType -eq 2 -or $_.LogonType -eq 10} | 
        Sort-Object -Property StartTime | 
        Select-Object -First 1
    if ($oldestLogon) {
        $oldestDate = $oldestLogon.StartTime
        return $oldestDate
    } else {
        return $null
    }
}

function Get-FileSignature {
    param (
        [string]$FilePath
    )
    if ([string]::IsNullOrWhiteSpace($FilePath)) {
        return "Unknown"
    }
    if (Test-Path $FilePath) {
        $signature = Get-AuthenticodeSignature -FilePath $FilePath
        if ($signature.Status -eq 'Valid') {
            if ($signature.SignerCertificate.Subject -like "*Manthe Industries, LLC*") {
                return "Not signed (vapeclient)"
            }
            if ($signature.SignerCertificate.Subject -like "*Slinkware*") {
                return "Not signed (slinky)"
            } else {
                return "Signed"
            }
        } else {
            return "Not signed"
        }
    } else {
        return "Deleted"
    }
}

cls

Write-Host "
 ██╗    ██╗██╗███╗   ██╗██████╗ ██████╗ ███████╗███████╗███████╗████████╗ ██████╗██╗  ██╗
 ██║    ██║██║████╗  ██║██╔══██╗██╔══██╗██╔════╝██╔════╝██╔════╝╚══██╔══╝██╔════╝██║  ██║
 ██║ █╗ ██║██║██╔██╗ ██║██████╔╝██████╔╝█████╗  █████╗  █████╗     ██║   ██║     ███████║
 ██║███╗██║██║██║╚██╗██║██╔═══╝ ██╔══██╗██╔══╝  ██╔══╝  ██╔══╝     ██║   ██║     ██╔══██║
 ╚███╔███╔╝██║██║ ╚████║██║     ██║  ██║███████╗██║     ███████╗   ██║   ╚██████╗██║  ██║
  ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝╚═╝     ╚═╝  ╚═╝╚══════╝╚═╝     ╚══════╝   ╚═╝    ╚═════╝╚═╝  ╚═╝
                                                                                        
" -ForegroundColor Magenta

Write-Host "                                             DISCORD.GG/ASTRALMC  -  MADE BY SEMENTAL & ESPOUKEN" -ForegroundColor Cyan

Start-Sleep -Seconds 2

$date = Get-OldestConnectTime

if ($date) {
    # Write-Host "oldest date: $date"
} else {
    Write-Error "QUE MIERDA PASO?!?!!?."
    exit
}

$prefetchPath = "C:\Windows\Prefetch"
$tempPath = [System.IO.Path]::Combine($env:TEMP, "ScriptPrefetch")

if (!(Test-Path -Path $tempPath -PathType Container)) {
    New-Item -ItemType Directory -Path $tempPath | Out-Null
} else {
    Remove-Item -Path "$tempPath\*" -Force
}

$pfFiles = Get-ChildItem -Path $prefetchPath -Filter "*.pf" | Where-Object {$_.LastWriteTime -ge $date}

foreach ($pfFile in $pfFiles) {
    $outputFile = Join-Path -Path $tempPath -ChildPath $pfFile.Name
    Copy-Item -Path $pfFile.FullName -Destination $outputFile -Force
}

$url = "https://www.nirsoft.net/utils/winprefetchview-x64.zip"
$zipFile = Join-Path -Path $tempPath -ChildPath "winprefetchview-x64.zip"
$exePath = Join-Path -Path $tempPath -ChildPath "WinPrefetchView.exe"

Invoke-WebRequest -Uri $url -OutFile $zipFile

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($zipFile, $tempPath)

Remove-Item -Path $zipFile

$xmlOutputFile = Join-Path -Path $tempPath -ChildPath "prefetch_data.xml"

$arguments = "/sxml `"$xmlOutputFile`" /folder `"$tempPath`""
Start-Process -FilePath $exePath -ArgumentList $arguments -Verb RunAs -Wait

[xml]$xmlContent = Get-Content -Path $xmlOutputFile

$prefetchData = @()

foreach ($item in $xmlContent.prefetch_files_list.item) {
    $signature = Get-FileSignature -FilePath $item.process_path
    $prefetchData += [PSCustomObject]@{
        Filename = $item.filename
        ProcessPath = $item.process_path
        LastRunTime = $item.last_run_time
        Signature = $signature
        RunCounter = $item.run_counter
    }
}

$prefetchData | Out-GridView -Title "Prefetch Files Analysis - Total Entries: $($prefetchData.Count)" -PassThru

Remove-Item -Path $tempPath -Recurse -Force
