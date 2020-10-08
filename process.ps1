if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    throw 'You gotta be admin'
}

$operatingFolder = "c:\temp\" # Folder all these files are in
$files = Get-ChildItem $operatingFolder"input\*.zip" # Folder the zip files to process are in
$tempExpandedFolder = $operatingFolder + "expanded\" # temp folder to expand the zip into
$tempDriveLetter = "T" # Drive to mount the VHD onto so files can be copied into it
$additionalScriptsFolder = $operatingFolder + "data" # Folder containing bat_ files to copy into VHD
$dispartCreateFile = $operatingFolder + "diskpart-script-create.txt" # temp disk part create file
$dispartDetachFile = $operatingFolder + "diskpart-script-detach.txt" # temp disk part detacth file
$diskCreateBufferPercent = 5 # percentage to add to extracted folder size to create the VHD with
$minMbToBuffer = 10 # if diskCreateBufferPercent creates a number less than this, then this number is used instead
$primaryOutputFolder = $operatingFolder + "output\" # where to put the output folders
$outputFolderHdd = $primaryOutputFolder + "game-hdd\" # where to put the vhd files
$outputFolderCd = $primaryOutputFolder + "game-cd\" # where to put the ISO image
$defaultGameProcessFile = $operatingFolder + "processGameDefault.psm1" # the powershell script to copy into game data folder

New-Item -ItemType Directory -Force -Path $tempExpandedFolder | Out-Null
Remove-Item $tempExpandedFolder"*" -Recurse -Force -Confirm:$false
New-Item -ItemType Directory -Force -Path $primaryOutputFolder | Out-Null
New-Item -ItemType Directory -Force -Path $outputFolderHdd | Out-Null
New-Item -ItemType Directory -Force -Path $outputFolderCd | Out-Null

Function Wait-Path {
    <#
    .SYNOPSIS
        Wait for a path to exist

    .DESCRIPTION
        Wait for a path to exist

        Default behavior will throw an error if we time out waiting for the path
        Passthru behavior will return true or false
        Behaviors above apply to the set of paths; unless all paths test successfully, we error out or return false

    .PARAMETER Path
        Path(s) to test
    
        Note
            Each path is independently verified with Test-Path.
            This means you can pass in paths from other providers.

    .PARAMETER Timeout
        Time to wait before timing out, in seconds

    .PARAMETER Interval
        Time to wait between each test, in seconds

    .PARAMETER Passthru
        When specified, return true if we see all specified paths, otherwise return false

        Note:
            If this is specified and we time out, we return false.
            If this is not specified and we time out, we throw an error.

    .EXAMPLE
        Wait-Path \\Path\To\Share -Timeout 30

        # Wait for \\Path\To\Share to exist, test every 1 second (default), time out at 30 seconds.

    .EXAMPLE
        $TempFile = [System.IO.Path]::GetTempFileName()
    
        if ( Wait-Path -Path $TempFile -Interval .5 -passthru )
        {
            Set-Content -Path $TempFile -Value "Test!"
        }
        else
        {
            Throw "Could not find $TempFile"
        }

        # Create a temp file, wait until we can see that file, testing every .5 seconds, write data to it.

    .EXAMPLE
        Wait-Path C:\Test, HKLM:\System

        # Wait until C:\Test and HKLM:\System exist

    .FUNCTIONALITY
        PowerShell Language

    #>
    [cmdletbinding()]
    param (
        [string[]]$Path,
        [int]$Timeout = 5,
        [int]$Interval = 1,
        [switch]$Passthru
    )

    $StartDate = Get-Date
    $First = $True

    Do {
        #Only sleep if this isn't the first run
        if ($First -eq $True) {
            $First = $False
        }
        else {
            Start-Sleep -Seconds $Interval
        }

        #Test paths and collect output
        [bool[]]$Tests = foreach ($PathItem in $Path) {
            Try {
                if (Test-Path $PathItem -ErrorAction stop) {
                    Write-Verbose "'$PathItem' exists"
                    $True
                }
                else {
                    Write-Verbose "Waiting for '$PathItem'"
                    $False
                }
            }
            Catch {
                Write-Error "Error testing path '$PathItem': $_"
                $False
            }
        }

        # Identify whether we can see everything
        $Return = $Tests -notcontains $False -and $Tests -contains $True
        
        # Poor logic, but we break the Until here
        # Did we time out?
        # Error if we are not passing through
        if ( ((Get-Date) - $StartDate).TotalSeconds -gt $Timeout) {
            if ( $Passthru ) {
                $False
                break
            }
            else {
                Throw "Timed out waiting for paths $($Path -join ", ")"
            }
        }
        elseif ($Return) {
            if ( $Passthru ) {
                $True
            }
            break
        }
    }
    Until( $False ) # We break out above
}

Function Write-DiskpartCreateFile {
    Param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [int] $vhdSize,
        [Parameter(Mandatory = $true, Position = 1)]
        [string] $vhdFileName
    )
    $stream = [System.IO.StreamWriter] $dispartCreateFile
    $fileContent = @"
CREATE VDISK FILE="$operatingFolder$vhdFileName" MAXIMUM=$vhdSize
ATTACH VDISK
CLEAN
CREATE PARTITION PRIMARY
FORMAT FS=FAT QUICK
ASSIGN LETTER=$tempDriveLetter
"@
    $stream.WriteLine($fileContent)
    $stream.close()
}
Function Write-DiskpartDetachFile {
    Param
    (
        [Parameter(Mandatory = $true, Position = 1)]
        [string] $vhdFileName
    )
    $stream = [System.IO.StreamWriter] $dispartDetachFile
    $fileContent = @"
SELECT VDISK FILE="$operatingFolder$vhdFileName"
DETACH VDISK
"@
    $stream.WriteLine($fileContent)
    $stream.close()
}
Function Remove-InvalidFileNameChars {
    param(
        [Parameter(Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [String]$Name
    )
  
    $invalidChars = ([IO.Path]::GetInvalidFileNameChars() -join '') + "'" # Diskpart seems to hate having a ' in the name
    $re = "[{0}]" -f [RegEx]::Escape($invalidChars)
    return ($Name -replace $re)
}
  
foreach ($file in $files) {
    Write-Output "Processing ${file}"
    $fileWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($file.FullName)
    $fileWithoutExtClean = Remove-InvalidFileNameChars $fileWithoutExt # clean up weird characters
    $newVhdName = $fileWithoutExtClean + ".vhd"

    Expand-Archive $file.FullName $tempExpandedFolder # extract the zip

    $hash = (Get-FileHash $file).Hash
    $gameDataFolder = $additionalScriptsFolder + "\" + $hash + "\"

    $gameScript = $gameDataFolder + "runme.bat_"
    if (Test-Path -LiteralPath $gameScript) {
        Copy-Item $gameScript -Destination "${tempExpandedFolder}runme.bat" # Copy the script from the gamescript folder into the extracted path ready to be moved
    }
    else {
        Write-Output "Unable to find config for game. provisioning"
        New-Item -ItemType Directory -Force -Path $gameDataFolder | Out-Null
        New-Item -Path $gameDataFolder"_"$fileWithoutExt -Force | Out-Null
        Set-Content -Path $gameScript -Value "REM $fileWithoutExt" # No game script file exists, so make one
        Add-Content -Path $gameScript -Value "d:"
        Add-Content -Path $gameScript -Value "dir"
    }

    $cdScript = $gameDataFolder + "cd.txt"
    if (Test-Path -LiteralPath $cdScript) {
        $stream = New-Object System.IO.StreamReader $cdScript
        while ($null -ne ($current_file = $stream.ReadLine())) {
            if (-not [string]::IsNullOrWhiteSpace($current_file)) {
                Move-Item -Path $tempExpandedFolder$current_file -Destination $outputFolderCd -Force -Confirm:$false
            }
        }
        $stream.close()
    }
    else {
        Set-Content -Path $cdScript -Value ""
    }

    $gameModule = $gameDataFolder + "process.psm1"
    if (Test-Path -LiteralPath $gameModule) {
        Import-Module -Name $gameModule -Scope "Local" -Force
        Format-Game $tempExpandedFolder
    }
    else {
        Copy-Item -Path $defaultGameProcessFile -Destination $gameModule
    }
    
    $extractedSize = ([Math]::Round((Get-ChildItem c:expanded -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -s).sum / 1Mb + 0.5, 0)) # roll through the extracted path and get its size
    $calculatedDiskBuffer = (($diskCreateBufferPercent / 100) * $extractedSize)
    if ($calculatedDiskBuffer -lt $minMbToBuffer) {
        $calculatedDiskBuffer = $minMbToBuffer # percentage to boot the VHD file size by is too small
    }
    $extractedSize = ([Math]::Round($calculatedDiskBuffer + $extractedSize + 0.5, 0))
    Write-DiskpartCreateFile $extractedSize $newVhdName # Create the script for making the VHD
    Write-DiskpartDetachFile $newVhdName # Create the script for unmounting the VHD

    DISKPART /S $dispartCreateFile | Out-Null # Create the VHD

    Wait-Path -Path ${tempDriveLetter}: # no idea if this works or not, but sometimes it takes a bit for the drive to mount
    Move-Item ${tempExpandedFolder}\* ${tempDriveLetter}: # move files into the mounted VHD
    DISKPART /S $dispartDetachFile | Out-Null # unmount the VHD
    Move-Item "$newVhdName" "$outputFolderHdd" -Force # put the VHD into the output folder
}

Remove-Item $dispartCreateFile -Force -Confirm:$false
Remove-Item $dispartDetachFile -Force -Confirm:$false
