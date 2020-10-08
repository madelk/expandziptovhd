function Format-Game {
    Param ([Parameter(Mandatory = $true, Position = 0)] [string] $directory)
    Move-Item $directory$((Get-ChildItem -Path $directory -Directory)[0].Name)"\*" $directory
    ((Get-Content -path ${directory}z.cfg -Raw) -replace 'path C:\\ESdagger\\arena2','path D:\arena2') | Set-Content -Path ${directory}z.cfg
    ((Get-Content -path ${directory}z.cfg -Raw) -replace 'pathCD C:\\ESdagger\\arena2','pathCD E:') | Set-Content -Path ${directory}z.cfg
}