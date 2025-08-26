cls
cls

Write-Host ""
Write-Host @"
 ██████╗  █████╗ ███╗   ███╗    ███████╗██╗ ██████╗ ███╗   ██╗ █████╗ ████████╗██╗   ██╗██████╗ ███████╗███████╗
 ██╔══██╗██╔══██╗████╗ ████║    ██╔════╝██║██╔════╝ ████╗  ██║██╔══██╗╚══██╔══╝██║   ██║██╔══██╗██╔════╝██╔════╝
 ██████╔╝███████║██╔████╔██║    ███████╗██║██║  ███╗██╔██╗ ██║███████║   ██║   ██║   ██║██████╔╝█████╗  ███████╗
 ██╔══██╗██╔══██║██║╚██╔╝██║    ╚════██║██║██║   ██║██║╚██╗██║██╔══██║   ██║   ██║   ██║██╔══██╗██╔══╝  ╚════██║
 ██████╔╝██║  ██║██║ ╚═╝ ██║    ███████║██║╚██████╔╝██║ ╚████║██║  ██║   ██║   ╚██████╔╝██║  ██║███████╗███████║
 ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝    ╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝╚══════╝                                                                          
"@ -ForegroundColor Magenta
Write-Host ""
Write-Host "                                                                                           made by espouken"
Write-Host ""

if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))  
{  
  Write-Warning "This script requires Administrator privileges. Please run as Administrator."
  exit
}

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
    Write-Host "No BAM entries found. This system may not be compatible."
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
                        'File Name' = $f
                    }
                }
            }
        }
    }
}

$ErrorActionPreference = 'Continue'

$ContenidoHtml = @'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>BAM Signature</title>
    <link
      href="https://fonts.googleapis.com/css2?family=Roboto:wght@300;400;700&display=swap"
      rel="stylesheet"
    />
    <style>
      :root {
        --background-color: #121212;
        --surface-color: #1e1e1e;
        --primary-color: #64b5f6;
        --text-color: #e0e0e0;
        --hover-color: #2196f3;
      }
      body {
        font-family: "Roboto", sans-serif;
        background-color: var(--background-color);
        color: var(--text-color);
        margin: 0;
        padding: 0px 20px;
        transition: all 0.1s ease;
      }
      h1 {
        color: var(--primary-color);
        text-align: center;
        margin-bottom: 30px;
        font-weight: 300;
        font-size: 2.5em;
      }
      .search-container {
        position: fixed;
        top: 20px;
        left: 20px;
        right: 20px;
        z-index: 1000;
        background-color: var(--surface-color);
        padding: 15px;
        border-radius: 8px;
        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
      }
      #search {
        width: calc(100% - 30px);
        padding: 10px 15px;
        border: none;
        border-radius: 4px;
        background-color: var(--background-color);
        color: var(--text-color);
        font-family: "Roboto", sans-serif;
        transition: all 0.1s ease;
      }
      #search:hover {
        outline: none;
        box-shadow: 0 0 0 2px #64b4f6d8;
      }
      #search:focus {
        outline: none;
        box-shadow: 0 0 0 2px var(--primary-color);
      }
      table {
        width: 100%;
        border-collapse: separate;
        border-spacing: 0 8px;
        margin-top: 90px; /* Ajustado para dejar espacio para la barra de búsqueda fija */
      }
      th,
      td {
        padding: 15px;
        text-align: left;
        transition: all 0.24s ease;
      }
      th {
        background-color: var(--surface-color);
        color: var(--primary-color);
        font-weight: 700;
        text-transform: uppercase;
        letter-spacing: 1px;
        cursor: pointer;
        position: relative;
      }
      th:hover {
        background-color: var(--hover-color);
        color: var(--background-color);
      }
      th.asc::after,
      th.desc::after {
        position: absolute;
        right: 8px;
        top: 50%;
        transform: translateY(-50%);
        font-size: 0.8em;
      }
      th.asc::after {
        content: "▲";
      }
      th.desc::after {
        content: "▼";
      }
      tr {
        background-color: var(--surface-color);
        transition: all 0.24s ease;
      }
      tr:hover {
        transform: translateY(-2px);
        scale: 1.013;
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
      }
      @keyframes fadeIn {
        from {
          opacity: 0;
          transform: translateY(20px);
        }
        to {
          opacity: 1;
          transform: translateY(0);
        }
      }
      .fade-in {
        /* animation: fadeIn 0.15s ease-out; */
      }
html, body {
  height: 100%;
  margin: 0;
}

body {
  display: flex;
  flex-direction: column;
}

main {
  flex: 1;
}

footer {
  text-align: center;
  font-size: 0.9em;
  color: var(--text-color);
  display: flex;
  justify-content: space-between;
  width: 100%;
  background-color: var(--background-color);
  padding: 10px 0;
}

footer a {
  color: var(--primary-color);
  text-decoration: none;
  position: relative;
  transition: color 0.18s ease-in-out;
}

footer a:hover {
  color: #33a3ff;
}

footer a::after {
  content: "";
  position: absolute;
  width: 100%;
  height: 2px;
  background-color: #33a3ff;
  color: #33a3ff;
  bottom: -1px;
  left: 0;
  transform: scaleX(0);
  transform-origin: right;
  transition: transform 0.18s ease-in-out;
}

footer a:hover::after {
  transform: scaleX(1);
  transform-origin: left;
}


    </style>
  </head>
 <body>
  <main>
    <div class="search-container fade-in">
      <input type="text" id="search" placeholder="Search..." />
    </div>

    <table id="entriesTable" class="fade-in">
      <thead>
        <tr>
          <th data-sort="time">Last Execution</th>
          <th data-sort="path">Path</th>
          <th data-sort="signature">Digital Signature</th>
          <th data-sort="fileName">File Name</th>
        </tr>
      </thead>
      <tbody></tbody>
    </table>
  </main>

  <footer class="fade-in">
    Made by espouken
    <a href="https://discordapp.com/users/1149799913727721485" target="_blank">Discord</a>
    <a href="https://github.com/spokwn" target="_blank">Github</a>
  </footer>


    <script>
      const entries = [
'@

foreach ($entry in $Bam) {
    $escapedTime = $entry.'Last Execution User Time'.Replace("\", "\\")
    $escapedPath = $entry.Path.Replace("\", "\\")
    $escapedSignature = $entry.'Digital Signature'.Replace("\", "\\")
    $escapedFileName = $entry.'File Name'.Replace("\", "\\")
    $ContenidoHtml += @"
        {
          time: "$escapedTime",
          path: "$escapedPath",
          signature: "$escapedSignature",
          fileName: "$escapedFileName"
        },
"@
}

$ContenidoHtml += @'
      ];

      let currentSort = { column: "time", direction: "asc" };

      function populateTable(data) {
        const tbody = document.querySelector("#entriesTable tbody");
        tbody.innerHTML = "";
        data.forEach((entry, index) => {
          const row = document.createElement("tr");
          row.className = "fade-in";
          row.style.animationDelay = `${index * 0.1}s`;
          row.innerHTML = `
                    <td>${entry.time}</td>
                    <td>${entry.path}</td>
                    <td>${entry.signature}</td>
                    <td>${entry.fileName}</td>
                `;
          tbody.appendChild(row);
        });
      }

      function applyFilters() {
        let filteredEntries = [...entries];
        const searchTerm = document
          .getElementById("search")
          .value.toLowerCase();

        filteredEntries = filteredEntries.filter((entry) =>
          Object.values(entry).some((value) =>
            value.toLowerCase().includes(searchTerm)
          )
        );

        filteredEntries.sort((a, b) => {
          const aValue = a[currentSort.column];
          const bValue = b[currentSort.column];
          if (currentSort.direction === "asc") {
            return aValue.localeCompare(bValue);
          } else {
            return bValue.localeCompare(aValue);
          }
        });

        populateTable(filteredEntries);
        updateSortIndicators();
      }

      function updateSortIndicators() {
        document.querySelectorAll("th").forEach((th) => {
          th.classList.remove("asc", "desc");
          if (th.dataset.sort === currentSort.column) {
            th.classList.add(currentSort.direction);
          }
        });
      }

      document.getElementById("search").addEventListener("input", applyFilters);

      document.querySelectorAll("th[data-sort]").forEach((th) => {
        th.addEventListener("click", () => {
          const column = th.dataset.sort;
          if (currentSort.column === column) {
            currentSort.direction =
              currentSort.direction === "asc" ? "desc" : "asc";
          } else {
            currentSort.column = column;
            currentSort.direction = "asc";
          }
          applyFilters();
        });
      });

      applyFilters();
    </script>
  </body>
</html>
'@


$htmlFilePath = Join-Path $env:TEMP "BAMKeyEntries.html"
$ContenidoHtml | Out-File -FilePath $htmlFilePath -Encoding UTF8


Start-Process $htmlFilePath
