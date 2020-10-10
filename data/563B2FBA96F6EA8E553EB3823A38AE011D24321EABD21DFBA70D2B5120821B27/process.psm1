function Format-Game {
    Param ([Parameter(Mandatory = $true, Position = 0)] [string] $directory)
    Move-Item $directory$((Get-ChildItem -Path $directory -Directory)[0].Name)"\*" $directory
    ((Get-Content -path ${directory}firstenc.cfg -Raw) -replace 'D:','E:') | Set-Content -Path ${directory}firstenc.cfg
}