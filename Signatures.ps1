# Asegurarse de que Clear-Host o cls esté disponible
if (Get-Command Clear-Host -ErrorAction SilentlyContinue) {
    Clear-Host
} elseif (Get-Command cls -ErrorAction SilentlyContinue) {
    cls
} else {
    Write-Warning "Clear-Host o cls no está disponible."
}

Write-Host @"

 ███████╗██╗ ██████╗ ███╗   ██╗ █████╗ ████████╗██╗   ██╗██████╗ ███████╗███████╗
 ██╔════╝██║██╔════╝ ████╗  ██║██╔══██╗╚══██╔══╝██║   ██║██╔══██╗██╔════╝██╔════╝
 ███████╗██║██║  ███╗██╔██╗ ██║███████║   ██║   ██║   ██║██████╔╝█████╗  ███████╗
 ╚════██║██║██║   ██║██║╚██╗██║██╔══██║   ██║   ██║   ██║██╔══██╗██╔══╝  ╚════██║
 ███████║██║╚██████╔╝██║ ╚████║██║  ██║   ██║   ╚██████╔╝██║  ██║███████╗███████║
 ╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝╚══════╝                                                                               
                                                                                
"@ -ForegroundColor Magenta
Write-Host ""
Write-Host "  Made by spokwn kjj - " -ForegroundColor Gray -NoNewline
Write-Host -ForegroundColor DarkMagenta "discord.gg/astralmc"
Write-Host ""

function Test-Admin {
    Try {
        $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
        return $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
    } Catch {
        Write-Warning "No se puede determinar si el script se está ejecutando como administrador."
        return $false
    }
}

if (!(Test-Admin)) {
    Write-Warning "Por favor, ejecute este script como administrador."
    Start-Sleep 10
    Exit
}

Start-Sleep -s 1

# Asegurarse de que Clear-Host o cls esté disponible nuevamente
if (Get-Command Clear-Host -ErrorAction SilentlyContinue) {
    Clear-Host
} elseif (Get-Command cls -ErrorAction SilentlyContinue) {
    cls
}

$possiblePathsFiles = @("Search results.txt", "paths.txt", "p.txt")
$pathsFilePath = $null

foreach ($file in $possiblePathsFiles) {
    if (Test-Path -Path $file) {
        $pathsFilePath = $file
        break
    }
}

if (-not $pathsFilePath) {
    Write-Warning "Ninguno de los archivos ($($possiblePathsFiles -join ', ')) existe."
    Start-Sleep 10
    Exit
}

Try {
    $lines = Get-Content $pathsFilePath
} Catch {
    Write-Warning "No se pudo leer el archivo: $pathsFilePath"
    Start-Sleep 10
    Exit
}

$stopwatch = [Diagnostics.Stopwatch]::StartNew()
$results = @()
$count = 0
$totalCount = $lines.Count

function Show-Progress {
    param (
        [int]$current,
        [int]$total
    )
    $percentage = [math]::Round(($current / $total) * 100)
    $progressBarLength = 50
    $progressChars = [math]::Round(($percentage / 100) * $progressBarLength)
    $progressBar = ("-" * $progressChars).PadRight($progressBarLength)
    Write-Host -NoNewline "`r[$progressBar] $percentage% Completo"
}

foreach ($line in $lines) {
    $count++
    Show-Progress -current $count -total $totalCount

    if ($line -match '([A-Za-z]):\\') {
        $index = $line.IndexOf($matches[0])
        if ($index -ge 0) {
            $path = $line.Substring($index)
            if (Test-Path -Path $path -PathType Leaf) {
                Try {
                    $fileName = Split-Path $path -Leaf
                    $signature = Get-AuthenticodeSignature $path 2>$null
                    $signatureStatus = if ($signature) { $signature.Status } else { "No signature" }

                    $fileDetails = New-Object PSObject
                    $fileDetails | Add-Member Noteproperty Name $fileName
                    $fileDetails | Add-Member Noteproperty Path $path
                    $fileDetails | Add-Member Noteproperty SignatureStatus $signatureStatus

                    $results += $fileDetails
                } Catch {
                    Write-Warning "No se pudo obtener la firma del archivo: $path"
                }
            }
        }
    }
}

$stopwatch.Stop()

$time = $stopwatch.Elapsed.Hours.ToString("00") + ":" + $stopwatch.Elapsed.Minutes.ToString("00") + ":" + $stopwatch.Elapsed.Seconds.ToString("00") + "." + $stopwatch.Elapsed.Milliseconds.ToString("000")

Write-Host "`n"
Write-Host "El escaneo tomó $time en ejecutarse." -ForegroundColor Yellow

$results | Out-GridView -PassThru -Title 'Resultados de las Firmas'
