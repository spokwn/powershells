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
Write-Host -ForegroundColor DarkMagenta "spokwn"
Write-Host ""

Start-Sleep -s 1
cls

function Get-DeviceMappings {
    $DynAssembly = New-Object System.Reflection.AssemblyName('SysUtils')
    $AssemblyBuilder = [AppDomain]::CurrentDomain.DefineDynamicAssembly($DynAssembly, [Reflection.Emit.AssemblyBuilderAccess]::Run)
    $ModuleBuilder = $AssemblyBuilder.DefineDynamicModule('SysUtils', $False)

    $TypeBuilder = $ModuleBuilder.DefineType('Kernel32', 'Public, Class')
    $PInvokeMethod = $TypeBuilder.DefinePInvokeMethod('QueryDosDevice', 'kernel32.dll', ([Reflection.MethodAttributes]::Public -bor [Reflection.MethodAttributes]::Static), [Reflection.CallingConventions]::Standard, [UInt32], [Type[]]@([String], [Text.StringBuilder], [UInt32]), [Runtime.InteropServices.CallingConvention]::Winapi, [Runtime.InteropServices.CharSet]::Auto)
    $DllImportConstructor = [Runtime.InteropServices.DllImportAttribute].GetConstructor(@([String]))
    $SetLastError = [Runtime.InteropServices.DllImportAttribute].GetField('SetLastError')
    $SetLastErrorCustomAttribute = New-Object Reflection.Emit.CustomAttributeBuilder($DllImportConstructor, @('kernel32.dll'), [Reflection.FieldInfo[]]@($SetLastError), @($true))
    $PInvokeMethod.SetCustomAttribute($SetLastErrorCustomAttribute)
    $Kernel32 = $TypeBuilder.CreateType()

    $Max = 65536
    $StringBuilder = New-Object System.Text.StringBuilder($Max)

    $driveMappings = Get-WmiObject Win32_Volume | Where-Object { $_.DriveLetter } | ForEach-Object {
        $ReturnLength = $Kernel32::QueryDosDevice($_.DriveLetter, $StringBuilder, $Max)

        if ($ReturnLength) {
            @{
                DriveLetter = $_.DriveLetter
                DevicePath = $StringBuilder.ToString().ToLower()
            }
        }
    }

    return $driveMappings
}

$driveMappings = Get-DeviceMappings

function Replace-DevicePaths($line, $driveMappings) {
    foreach ($driveMapping in $driveMappings) {
        $line = $line.Replace($driveMapping.DevicePath, $driveMapping.DriveLetter)
    }
    return $line
}

$possiblePathsFiles = @("Search results.txt", "paths.txt", "p.txt")
$pathsFilePath = $possiblePathsFiles | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $pathsFilePath) {
    Write-Warning "None of the files ($($possiblePathsFiles -join ', ')) exist."
    Start-Sleep 3
    Exit
}

Try {
    $lines = Get-Content $pathsFilePath
} Catch {
    Write-Warning "Failed to read the file: $pathsFilePath"
    Start-Sleep 3
    Exit
}

$stopwatch = [Diagnostics.Stopwatch]::StartNew()
$results = @()

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]

    Write-Progress -Activity "Processing lines" -Status "$($i + 1) of $($lines.Count)" -PercentComplete (($i / $lines.Count) * 100)
    $line = Replace-DevicePaths -line $line -driveMappings $driveMappings

    if ($line -match '([A-Za-z]).') {
        if ($line -match '([A-Za-z]):\\') {
            $index = $line.IndexOf($matches[0])
            if ($index -ge 0) {
                $path = $line.Substring($index)
                if (-not (Test-Path -Path $path -PathType Leaf)) {
                    $results += [pscustomobject]@{
                        Name = "DELETED"
                        Path = $line.Substring($index)
                        SignatureStatus = "DELETED"
                    }
                    continue
                }
                Try {
                    $fileName = Split-Path $path -Leaf
                    $signature = Get-AuthenticodeSignature $path 2>$null
                    $signatureStatus = $signature.Status
                    $signerName = $signature.SignerCertificate.Subject

                    if ($signerName -like "*Manthe Industries, LLC*") {
                        $signatureStatus = "NotSigned (vape client)"
                    }

                    if ($signerName -like "*Slinkware*") {
                        return "Not signed (slinky)"
                    }

                    $results += [pscustomobject]@{
                        Name = $fileName
                        Path = $path
                        SignatureStatus = $signatureStatus
                    }
                } Catch {
                    Write-Warning "Failed to obtain signature for the file: $path"
                }
            }
        }
    }
}


$stopwatch.Stop()

$time = $stopwatch.Elapsed.ToString("hh\:mm\:ss\.fff")

Write-Host "`n"
Write-Host "Scanning took $time to execute." -ForegroundColor Yellow

$results | Out-GridView -PassThru -Title 'Signature Results'
