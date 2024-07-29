# supress output
$VerbosePreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'

# function to update nuget
function Ensure-NuGet {
    if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
        Install-PackageProvider -Name NuGet -Force -Scope CurrentUser | Out-Null
    }
    else {
        $nuget = Get-PackageProvider -Name NuGet
        $latestNuGet = Find-PackageProvider -Name NuGet -Force | Sort-Object Version -Descending | Select-Object -First 1
        if ($nuget.Version -lt $latestNuGet.Version) {
            Install-PackageProvider -Name NuGet -Force -Scope CurrentUser | Out-Null
        }
    }
}

# update NuGet for PSSQLite
Ensure-NuGet

# PSSQLite downloading
if (-not (Get-Module -ListAvailable -Name PSSQLite)) {
    Install-Module -Name PSSQLite -Force -Scope CurrentUser -ErrorAction Stop | Out-Null
}

# Import PSSQLite module
Import-Module PSSQLite -ErrorAction Stop

# get folder path
function Get-ActivitiesCacheFolder {
    $userProfile = $env:USERPROFILE
    $basePath = Join-Path $userProfile "AppData\Local\ConnectedDevicesPlatform"
    
    # local account activitiescache
    $localFolder = Get-ChildItem $basePath -Directory | Where-Object { $_.Name -like "L.*" } | Select-Object -First 1
    if ($localFolder) {
        return $localFolder.FullName
    }
    
    # microsoft activitiescache
    $microsoftIdPath = "HKCU:\software\Microsoft\IdentityCRL\UserExtendedProperties"
    $microsoftId = (Get-ItemProperty -Path $microsoftIdPath -ErrorAction SilentlyContinue).UserId
    if ($microsoftId) {
        $msFolder = Join-Path $basePath $microsoftId
        if (Test-Path $msFolder) {
            return $msFolder
        }
    }
    
    # azure AD activitiescache
    $aadFolder = Get-ChildItem $basePath -Directory | Where-Object { $_.Name -like "AAD.*" } | Select-Object -First 1
    if ($aadFolder) {
        return $aadFolder.FullName
    }
    
    Write-Error "Unable to find ActivitiesCache folder"
    return $null
}

# cleanup of text
function Get-CleanApplicationPath {
    param (
        [string]$inputString
    )
    
    try {
        if ($inputString -match '^\{.*\}$') {
            # json object
            $jsonObject = $inputString | ConvertFrom-Json
            if ($jsonObject.PSObject.Properties['application']) {
                return $jsonObject.application.Replace("\\", "\")
            }
        } elseif ($inputString -match '^\[.*\]$') {
            # json
            $jsonArray = $inputString | ConvertFrom-Json
            $appPaths = $jsonArray | ForEach-Object {
                if ($_.platform -eq "x_exe_path" -or $_.platform -eq "packageId") {
                    $_.application
                }
            } | Where-Object { $_ -ne "" } | Select-Object -Unique
            return ($appPaths -join ", ").Replace("\\", "\")
        } elseif ($inputString -match '\{\{.*\}\}') {
            # multiple path string handling
            $paths = $inputString -split ', ' | ForEach-Object {
                if ($_ -match '\{(.*?)\}') {
                    $matches[1]
                }
            } | Select-Object -Unique
            return ($paths -join ", ").Replace("\\", "\")
        } elseif ($inputString -match '\{[0-9A-F-]{36}\}\\') {
            # guid stuff
            return $inputString.Replace("\\", "\")
        }
        return $inputString.Replace("\\", "\")
    }
    catch {
        return $inputString
    }
}

# check folder path
$folder = Get-ActivitiesCacheFolder
if (-not $folder) {
    exit 1
}

# path
$dbPath = Join-Path $folder "ActivitiesCache.db"

# SQL to get stuff
$query = @"
SELECT 
    AppId as Application,
    datetime(StartTime, 'unixepoch', 'localtime') as StartTime
FROM Activity
ORDER BY StartTime DESC
"@

# query
$results = Invoke-SqliteQuery -DataSource $dbPath -Query $query -ErrorAction Stop

# cleanup things
$cleanResults = $results | ForEach-Object {
    [PSCustomObject]@{
        Application = Get-CleanApplicationPath $_.Application
        StartTime = $_.StartTime
    }
} | Where-Object { $_.Application -ne "" }

# timzone
$UserTime = (Get-TimeZone).DisplayName

# displaying
$cleanResults | Out-GridView -PassThru -Title "ActivitiesCache entries $($cleanResults.count) - User TimeZone: ($UserTime)"
