# By semental and espouken

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
# conseguir el oldest entry
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
    # Limpiar el directorio de salida si ya existe
    Remove-Item -Path "$tempPath\*" -Force
}

# todos los PF con la fecha de instancia o depsues
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

$arguments = "/folder `"$tempPath`""
Start-Process -FilePath $exePath -ArgumentList $arguments -Verb RunAs -Wait

# Cleanup borrar luego de terminado de ejecutar
Remove-Item -Path $tempPath -Recurse -Force
