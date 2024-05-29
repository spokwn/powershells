cls
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

Start-Sleep -s 1
cls

$possiblePathsFiles = @("Search results.txt", "paths.txt", "p.txt")
$pathsFilePath = $possiblePathsFiles | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $pathsFilePath) {
    Write-Warning "Ninguno de los archivos ($($possiblePathsFiles -join ', ')) existe."
    Start-Sleep 3
    Exit
}

Try {
    $lines = Get-Content $pathsFilePath
} Catch {
    Write-Warning "No se pudo leer el archivo: $pathsFilePath"
    Start-Sleep 3
    Exit
}

$stopwatch = [Diagnostics.Stopwatch]::StartNew()
$results = @()

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]

    Write-Progress -Activity "Procesando líneas" -Status "$($i + 1) de $($lines.Count)" -PercentComplete (($i / $lines.Count) * 100)

    if ($line -match '([A-Za-z]).') {
        if ($line -match '([A-Za-z]):\\') {
            $index = $line.IndexOf($matches[0])
            if ($index -ge 0) {
                $path = $line.Substring($index)
                if (Test-Path -Path $path -PathType Leaf) {
                    Try {
                        $fileName = Split-Path $path -Leaf
                        $signature = Get-AuthenticodeSignature $path 2>$null
                        $signatureStatus = $signature.Status

                        $results += [pscustomobject]@{
                            Name = $fileName
                            Path = $path
                            SignatureStatus = $signatureStatus
                        }
                    } Catch {
                        Write-Warning "No se pudo obtener la firma del archivo: $path"
                    }
                }
            }
        }
    }
}

$stopwatch.Stop()

$time = $stopwatch.Elapsed.ToString("hh\:mm\:ss\.fff")

Write-Host "`n"
Write-Host "El escaneo tomó $time en ejecutarse." -ForegroundColor Yellow

$results | Out-GridView -PassThru -Title 'Resultados de las Firmas'
