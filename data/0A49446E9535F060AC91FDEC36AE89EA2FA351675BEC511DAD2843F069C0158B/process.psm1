function Format-Game {
    Param ([Parameter(Mandatory = $true, Position = 0)] [string] $directory)
    Move-Item $directory$((Get-ChildItem -Path $directory -Directory)[0].Name)"\*" $directory
    ((Get-Content -path ${directory}"hospital\hospital.cfg" -Raw) -replace 'D:\\HOSP','E:\HOSP') | Set-Content -Path ${directory}"hospital\hospital.cfg"
    ((Get-Content -path ${directory}"hospital\sound\mdi.ini" -Raw) -replace 'SBPRO2.MDI','SBLASTER.MDI') | Set-Content -Path ${directory}"hospital\sound\mdi.ini"
}