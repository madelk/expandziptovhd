Use https://archive.org/details/8-gb-dos-71-qemm.-7z but with this `drv` folder copied into it https://github.com/MiSTer-devel/ao486_MiSTer/tree/master/releases/drv

Put this repo into `c:\temp` add zip files from Total dos collection into input run `.\process.ps1` as an admin

Put your `8-gb-dos-71-qemm` into your `ao486` folder along with a `game-cd` folder and `game-hdd` in the root of that `ao486` folder. Mount `8-gb-dos-71-qemm` as `0-0` and your chosen game as `0-1`

# TODO
* WC1 and WC2 both use the same CD file names. I'll need to rename, but cue files will also have to have their text updated
* Check MD5 on source and destination files, such and VHDs and ISOs. Delete the source if they match. This will prevent updating the timestamp, that's handy when copying only updated files over SFTP

* Elite Plus (1991)
* Frontier - First Encounters (1995)
* Star Wars TIE Fighter (Collector's CD-ROM) (1995)
* Theme Hospital (1997)
* Theme Park (1994)
* Wing Commander II Deluxe Edition (1992)

# CONTRIBUTE
## If your game has an ISO
* Add a line to cd.txt with the path to the ISO, or a line for the cue and another line for the bin
* Add a line to the runme.bat_ that refrences the ISO, such as `c:\drv\imgset ide10 game-cd/Daggerfall.ISO`
## If you want to run processing on your game before it's added to the VHD
Edit process.psm1
``` powershell
    # Moves files inside the first subdirectory into this directory
    Move-Item $directory$((Get-ChildItem -Path $directory -Directory)[0].Name)"\*" $directory

    # Replace the text hello\world with happy\puppy inside z.cfg
    ((Get-Content -path ${directory}z.cfg -Raw) -replace 'hello\\world','happy\puppy') | Set-Content -Path ${directory}z.cfg
```
## If you want to run commands that run inside the vhd
Edit runme.bat_