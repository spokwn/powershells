cls

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
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}
if (!(Test-Admin)) {
    Write-Warning "Please Run This Script as Admin."
    Start-Sleep 10
    Exit
}

Start-Sleep -s 1

cls

# Lista de archivos posibles
$possiblePathsFiles = @("Search results.txt", "paths.txt", "p.txt")
$pathsFilePath = $null

# Encontrar el primer archivo existente en la lista
foreach ($file in $possiblePathsFiles) {
    if (Test-Path -Path $file) {
        $pathsFilePath = $file
        break
    }
}

if (-not $pathsFilePath) {
    Write-Warning "None of the files ($($possiblePathsFiles -join ', ')) exist."
    Start-Sleep 10
    Exit
}

$lines = Get-Content $pathsFilePath
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
    Write-Host -NoNewline "`r[$progressBar] $percentage% Complete"
}

foreach ($line in $lines) {
    $count++
    Show-Progress -current $count -total $totalCount

    # Verificar si la línea contiene `:\`
    if ($line -match '([A-Za-z]):\\') {
        $index = $line.IndexOf($matches[0])
        if ($index -ge 0) {
            $path = $line.Substring($index)
            
            # Verificar si la ruta es un archivo existente
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
                    # Manejar excepciones si es necesario
                }
            }
        }
    }
}

$stopwatch.Stop()

$time = $stopwatch.Elapsed.Hours.ToString("00") + ":" + $stopwatch.Elapsed.Minutes.ToString("00") + ":" + $stopwatch.Elapsed.Seconds.ToString("00") + "." + $stopwatch.Elapsed.Milliseconds.ToString("000")

Write-Host "`n"
Write-Host "The scan took $time to run." -ForegroundColor Yellow

$results | Out-GridView -PassThru -Title 'Signatures Results'
