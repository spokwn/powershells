$ErrorActionPreference = "Stop"

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Run this script as Administrator."
    exit 1
}

function Get-OldestLogonTime {
    $oldestLogon = Get-CimInstance Win32_LogonSession | 
        Where-Object { $_.LogonType -in 2, 10 } | 
        Sort-Object StartTime | 
        Select-Object -First 1

    if ($oldestLogon) {
        return $oldestLogon.StartTime
    } else {
        return $null
    }
}

function Get-ActivityFlags {
    param ([string]$generics)
    
    if (-not $generics) { return @() }
    
    return [regex]::Matches($generics, '\[(\w*)\]') | 
        ForEach-Object { $_.Groups[1].Value } | 
        Where-Object { $_ -ne '' } | 
        Select-Object -Unique
}

function Format-ActivityFlags {
    param ([array]$flags)
    
    if (-not $flags) { return "none" }
    
    return ($flags | ForEach-Object { "Flagged [$_]" }) -join "  "
}

function Get-ActivitiesCacheParser {
    $url = "https://github.com/spokwn/ActivitiesCache-execution/releases/download/v0.6.1/ActivitiesCacheParser.exe"
    $outPath = Join-Path $env:TEMP "ActivitiesCacheParser.exe"
    
    try {
        Invoke-WebRequest -Uri $url -OutFile $outPath -UseBasicParsing
        return $outPath
    } catch {
        Write-Error "Failed to download ActivitiesCacheParser: $_"
        exit 1
    }
}

function Invoke-ActivitiesCacheParser {
    param ([string]$parserPath, [string]$outputPath, [bool]$notSigned)
    
    $arguments = @($outputPath)
    if ($notSigned) {
        $arguments += "-n"
    }
    
    $output = & $parserPath $arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "ActivitiesCacheParser failed (Exit code: $LASTEXITCODE): $output"
    }
}

function Get-ParsedActivities {
    param ([string]$content)
    
    return $content -split "------------------------" | 
        Where-Object { $_ -match '\S' } | 
        ForEach-Object {
            $activity = $_ -split "`n"
            $startTimeLine = $activity | Where-Object { $_ -match "StartTime:" }
            $startTimeString = ($startTimeLine -split ": ")[1].Trim()
            
            try {
                $startTime = [DateTime]$startTimeString
            } catch {
                Write-Warning "Unable to parse date: $startTimeString"
                $startTime = [DateTime]::MinValue
            }
            
            [PSCustomObject]@{
                RawData = $_
                StartTime = $startTime
            }
        } | Sort-Object StartTime -Descending
}

function Format-ActivityOutput {
    param (
        [Parameter(ValueFromPipeline=$true)]
        [PSCustomObject]$activity
    )
    
    process {
        $lines = $activity.RawData -split "`n"
        $app = ($lines -match "Application: (.+)")[0] -replace "Application: ", ""
        $sig = ($lines -match "Digital signature: (.+)")[0] -replace "Digital signature: ", ""
        $generics = ($lines -match "Generics: (.+)")[0] -replace "Generics: ", ""
        $start = ($lines -match "StartTime: (.+)")[0] -replace "StartTime: ", ""
        $end = ($lines -match "EndTime: (.+)")[0] -replace "EndTime: ", ""
        
        $flags = Get-ActivityFlags $generics
        
        "Application: $app"
        "Digital signature: $sig"
        "Generics: $(Format-ActivityFlags $flags)"
        "StartTime: $start"
        "EndTime: $end"
        "------------------------"
    }
}

# Main
Clear-Host
Write-Host "`n                     ActivitiesCache`n" -ForegroundColor Red
Write-Host "                                        made by espouken`n" -ForegroundColor White

$parserPath = Get-ActivitiesCacheParser
$outputPath = "C:\Users\$env:USERNAME\activities.txt"

$notSignedOnly = $false

Invoke-ActivitiesCacheParser $parserPath $outputPath $notSignedOnly

$oldestLogon = Get-OldestLogonTime
if ($null -eq $oldestLogon) {
    Write-Error "Failed to retrieve oldest logon time."
    exit 1
}

$content = Get-Content $outputPath -Raw
$activities = Get-ParsedActivities $content

$activities | 
    Where-Object { $_.StartTime -gt $oldestLogon } | 
    Format-ActivityOutput

# Cleanup
Remove-Item $parserPath, $outputPath -Force -ErrorAction SilentlyContinue