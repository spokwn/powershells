cls
cls

Write-Host @"

 ██████╗  █████╗ ███╗   ███╗    ███████╗██╗ ██████╗ ███╗   ██╗ █████╗ ████████╗██╗   ██╗██████╗ ███████╗███████╗
 ██╔══██╗██╔══██╗████╗ ████║    ██╔════╝██║██╔════╝ ████╗  ██║██╔══██╗╚══██╔══╝██║   ██║██╔══██╗██╔════╝██╔════╝
 ██████╔╝███████║██╔████╔██║    ███████╗██║██║  ███╗██╔██╗ ██║███████║   ██║   ██║   ██║██████╔╝█████╗  ███████╗
 ██╔══██╗██╔══██║██║╚██╔╝██║    ╚════██║██║██║   ██║██║╚██╗██║██╔══██║   ██║   ██║   ██║██╔══██╗██╔══╝  ╚════██║
 ██████╔╝██║  ██║██║ ╚═╝ ██║    ███████║██║╚██████╔╝██║ ╚████║██║  ██║   ██║   ╚██████╔╝██║  ██║███████╗███████║
 ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝    ╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝╚══════╝                                                                          
"@ -ForegroundColor Magenta
Write-Host ""
Write-Host "                                                      Made by spokwn kjj - " -ForegroundColor Gray -NoNewline
Write-Host -ForegroundColor DarkMagenta "discord.gg/astralmc"
Write-Host ""

function Get-OldestConnectTime {
    $oldestLogon = Get-CimInstance -ClassName Win32_LogonSession | 
        Where-Object {$_.LogonType -eq 2 -or $_.LogonType -eq 10} | 
        Sort-Object -Property StartTime | 
        Select-Object -First 1
    if ($oldestLogon) {
        return $oldestLogon.StartTime
    } else {
        return $null
    }
}


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

function Convert-DevicePathToDriveLetter {
    param (
        [string]$DevicePath,
        $DeviceMappings
    )
    foreach ($mapping in $DeviceMappings) {
        if ($DevicePath -like ($mapping.DevicePath + "*")) {
            return $DevicePath -replace [regex]::Escape($mapping.DevicePath), $mapping.DriveLetter
        }
    }
    return $DevicePath
}

function Get-FileSignature {
    param (
        [string]$FilePath
    )
    if (Test-Path $FilePath) {
        $signature = Get-AuthenticodeSignature -FilePath $FilePath
        if ($signature.Status -eq 'Valid') {
            return "Signed"
        } else {
            return "Not signed"
        }
    } else {
        return "Deleted"
    }
}

$oldestConnectTime = Get-OldestConnectTime

$deviceMappings = Get-DeviceMappings

$ErrorActionPreference = 'SilentlyContinue'

if (!(Get-PSDrive -Name HKLM -PSProvider Registry)){
    Try{New-PSDrive -Name HKLM -PSProvider Registry -Root HKEY_LOCAL_MACHINE}
    Catch{}
}

$bv = ("bam", "bam\State")
$Users = @()
foreach($ii in $bv){
    $Users += Get-ChildItem -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$($ii)\UserSettings\" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty PSChildName
}

if ($Users.Count -eq 0) {
    Write-Host "No se encontraron entradas BAM. Es posible que este sistema no sea compatible."
    exit
}

$rpath = @("HKLM:\SYSTEM\CurrentControlSet\Services\bam\","HKLM:\SYSTEM\CurrentControlSet\Services\bam\state\")

$UserTime = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" -ErrorAction SilentlyContinue).TimeZoneKeyName
$UserBias = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" -ErrorAction SilentlyContinue).ActiveTimeBias
$UserDay = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" -ErrorAction SilentlyContinue).DaylightBias

$Bam = @()
Foreach ($Sid in $Users) {
    foreach($rp in $rpath){
        $BamItems = Get-Item -Path "$($rp)UserSettings\$Sid" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Property
        
        Try{
            $objSID = New-Object System.Security.Principal.SecurityIdentifier($Sid)
            $User = $objSID.Translate( [System.Security.Principal.NTAccount]) 
            $User = $User.Value
        }
        Catch{$User=""}
        
        ForEach ($Item in $BamItems){
            $Key = Get-ItemProperty -Path "$($rp)UserSettings\$Sid" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $Item
    
            If($key.length -eq 24){
                $Hex=[System.BitConverter]::ToString($key[7..0]) -replace "-",""
                $Bias = -([convert]::ToInt32([Convert]::ToString($UserBias,2),2))
                $TimeUser = (Get-Date ([DateTime]::FromFileTimeUtc([Convert]::ToInt64($Hex, 16))).addminutes($Bias) -Format "yyyy-MM-dd HH:mm:ss") 
                
                if ([DateTime]::ParseExact($TimeUser, "yyyy-MM-dd HH:mm:ss", $null) -ge $oldestConnectTime) {
                    $f = if((((split-path -path $item) | ConvertFrom-String -Delimiter "\\").P3)-match '\d{1}')
                    {Split-path -leaf ($item).TrimStart()} else {$item}
                    
                    $path = Convert-DevicePathToDriveLetter -DevicePath $item -DeviceMappings $deviceMappings
                    
                    $signature = Get-FileSignature -FilePath $path
                    
                    $Bam += [PSCustomObject]@{
                        'Last Execution User Time' = $TimeUser
                        Path = $path
                        'Digital Signature' = $signature
                    }
                }
            }
        }
    }
}

$ErrorActionPreference = 'Continue'

$Bam | Out-GridView -PassThru -Title "BAM key entries $($Bam.count) - User TimeZone: ($UserTime)"
