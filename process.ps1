if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    throw 'You gotta be admin'
}

$operatingFolder = "c:\temp\"
$files = Get-ChildItem $operatingFolder"input\*.zip"
# $tempVhd = $operatingFolder + "temp.vhd"
$tempExpandedFolder = $operatingFolder + "expanded"
$tempDriveLetter = "T"
$additionalScriptsFolder = $operatingFolder + "data"
$dispartCreateFile = $operatingFolder + "diskpart-script-create.txt"
$dispartDetachFile = $operatingFolder + "diskpart-script-detach.txt"
$diskCreateBuffer = 5

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

Remove-Item $tempExpandedFolder"\*" -Recurse -Force -Confirm:$false
foreach ($file in $files) {
    Write-Output "Processing ${file}"
    $fileWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($file.FullName)
    $hash = (Get-FileHash $file).Hash
    $gameScript = $additionalScriptsFolder + "\" + $hash + ".bat_"
    Expand-Archive $file.FullName $tempExpandedFolder
    if (Test-Path -Path $gameScript) {
        Copy-Item $gameScript -Destination "${tempExpandedFolder}\runme.bat"
    }
    else {
        Set-Content -Path $gameScript -Value "REM $fileWithoutExt"
    }
    $extractedSize = ([Math]::Round((Get-ChildItem c:expanded -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -s).sum / 1Mb + 0.5, 0)) + $diskCreateBuffer
    $newVhdName = $fileWithoutExt + ".vhd"
    Write-DiskpartCreateFile $extractedSize $newVhdName
    Write-DiskpartDetachFile $newVhdName
    DISKPART /S $dispartCreateFile | Out-Null
    Move-Item ${tempExpandedFolder}\* ${tempDriveLetter}:
    DISKPART /S $dispartDetachFile | Out-Null
    Move-Item "$newVhdName" C:\temp\output -Force
}

Remove-Item $dispartCreateFile -Force -Confirm:$false
Remove-Item $dispartDetachFile -Force -Confirm:$false
