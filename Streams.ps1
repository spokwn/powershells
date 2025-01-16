Write-Host "Using directory: $Folder" -ForegroundColor White
$response = Read-Host "Do you want to search recursively in subdirectories? (y/n)"
$Folder = (Get-Location).Path


if ($response -match '^(y|yes)$') {
    $levels = Read-Host "How many levels of subdirectories do you want to search? Enter a number or type 'all' for all subdirectories"
    if ($levels -match '^(all)$') {
        $Files = Get-ChildItem -Path $Folder -Recurse -ErrorAction Ignore
    } elseif ($levels -match '^\d+$') {
        $Files = Get-ChildItem -Path $Folder -Recurse -Depth ([int]$levels) -ErrorAction Ignore
    } else {
        Write-Host "Invalid input. Proceeding with unlimited recursion." -ForegroundColor Yellow
        $Files = Get-ChildItem -Path $Folder -Recurse -ErrorAction Ignore
    }
} else {
    $Files = Get-ChildItem -Path $Folder -ErrorAction Ignore
}

$i = 0

$results = ForEach ($File in $Files) {
    $i++
    try {
        $Stream = (Get-Item -LiteralPath $File.FullName -Stream *).Stream | Out-String | ConvertFrom-String -PropertyNames St1, St2, St3, St4, St5
    } catch {
        $Stream = ""
    }

    try {
        $Zone = Get-Content -Stream Zone.Identifier -LiteralPath $File.FullName -ErrorAction Ignore | Out-String | ConvertFrom-String -PropertyNames Z1, Z2, Z3, Z4, Z5
    } catch {
        $Zone = ""
    }

    try {
        $hashMD5 = (Get-FileHash -LiteralPath $File.FullName -Algorithm MD5 -ErrorAction Ignore).Hash
    } catch {
        $hashMD5 = ""
    }

    Write-Progress -Activity "Collecting information for File: $File" -Status "File $i of $($Files.Count)" -PercentComplete (($i / $Files.Count) * 100)

    [PSCustomObject]@{ 
        Path                  = Split-Path -LiteralPath $File.FullName 
        'File/Directory Name' = $File.Name
        'MD5 Hash (File Hash only)' = $hashMD5
        'Owner (name/sid)'    = (Get-Acl -LiteralPath $File.FullName).Owner
        Length                = (Get-ChildItem -LiteralPath $File.FullName -Force).Length
        LastAccessTime        = (Get-ItemProperty -LiteralPath $File.FullName).LastAccessTime
        LastWriteTime         = (Get-ItemProperty -LiteralPath $File.FullName).LastWriteTime
        Attributes            = (Get-ItemProperty -LiteralPath $File.FullName).Mode
        Stream1               = $Stream.St1
        Stream2               = $Stream.St2
        Stream3               = $Stream.St3
        Stream4               = $Stream.St4
        ZoneId1               = $Zone.Z2
        ZoneId2               = $Zone.Z3
        ZoneId3               = $Zone.Z4
        ZoneId4               = $Zone.Z5
    }
}

$finalOutput = $results | Out-GridView -PassThru -Title "Zone.Identifier stream contents for files in folder $Folder"

[gc]::Collect()
