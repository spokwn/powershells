Function Get-Folder($initialDirectory)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")|Out-Null
    $foldername = New-Object System.Windows.Forms.FolderBrowserDialog
    $foldername.rootfolder = "MyComputer"
	$foldername.Description = "Select a directory to scan files for Alternate Data Streams"
	$foldername.ShowNewFolderButton = $false
	
    if($foldername.ShowDialog() -eq "OK")
		{
        $folder += $foldername.SelectedPath
		 }
	        else  
        {
            Write-Host "(Streams.ps1):" -f Yellow -nonewline; Write-Host " User Cancelled" -f White
			exit
        }
    return $Folder

	}

$Folder = Get-Folder
Write-Host "(Streams.ps1):" -f Yellow -nonewline; write-host " Selected directory: ($Folder)" -f White

$Files = Get-ChildItem -Path $Folder -recurse -ErrorAction Ignore
$1=1

			  
$results = ForEach ($File in $Files) {$i++

	# Check that Alternate Data Streams exist, and if so split the output up to 5 variables
	try{$Stream = (Get-Item -literalpath $File.FullName -Stream *).stream|out-string|ConvertFrom-String -PropertyNames St1, St2, St3, Stl4, Stl5}
		Catch{$Stream = ""}
	
	try{$Zone = Get-Content -Stream Zone.Identifier -literalpath $File.FullName -ErrorAction Ignore|out-string|ConvertFrom-String -PropertyNames Z1, Z2, Z3, Z4, Z5}
		Catch{$Zone = ""}

	try{$hashMD5 = (Get-FileHash -literalpath $File.FullName -Algorithm MD5 -ErrorAction Ignore).Hash}catch{$hash=""}
	
	Write-Progress -Activity "Collecting information for File: $file" -Status "File $i of $($Files.Count))" -PercentComplete (($i / $Files.Count) * 100)  

	[PSCustomObject]@{ 
	Path = Split-Path -literalpath $File.FullName 
	'File/Directory Name' = $File 
	'MD5 Hash (File Hash only)' = $hashMD5
	'Owner (name/sid)' = (Get-Acl -literalpath $file.FullName).owner
	Length = (Get-ChildItem -literalpath $File.FullName -force).length
	LastAccessTime = (Get-ItemProperty -literalpath $File.FullName).lastaccesstime
	LastWriteTime = (Get-ItemProperty -literalpath $File.FullName).lastwritetime
	Attributes = (Get-ItemProperty -literalpath $File.FullName).Mode
	Stream1 = $Stream.St1
	Stream2 = $Stream.St2
	Stream3 = $Stream.St3
	Stream4 = $Stream.St4
	ZoneId1 = $Zone.Z2
	ZoneId2 = $Zone.Z3
	ZoneId3 = $Zone.Z4
	ZoneId4 = $Zone.Z5
	}
	
 }

$filenameFormat = $env:userprofile + "\desktop\streams" + " "  + (Get-Date -Format "dd-MM-yyyy hh-mm") + ".txt"

$results|Out-GridView -PassThru -Title "File Zone.Identifier Stream contents files in folder $Folder" |Out-File -FilePath $filenameFormat -Encoding Unicode
[gc]::Collect()
