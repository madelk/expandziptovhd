function Format-Game {
    Param ([Parameter(Mandatory = $true, Position = 0)] [string] $directory)
    Move-Item $directory"lba\lba\*" $directory"lba\"
    Move-Item $directory"lba\ULTRASND\*" $directory"ULTRASND\"
}