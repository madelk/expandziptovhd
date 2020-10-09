function Format-Game {
    Param ([Parameter(Mandatory = $true, Position = 0)] [string] $directory)
    Move-Item $directory"duke3d\duke3d\*" $directory"duke3d\"
    Move-Item $directory"duke3d\ULTRASND\*" $directory"ULTRASND\"
}