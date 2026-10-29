param([ValidateSet('all','quarry','wise_mountains','volcanic','spore_forest','radiation_wasteland','crystal_wastes','insect_colony','alien_infected')][string]$Biome='all')
$extRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$extEngine='C:\Users\User1\Documents\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64_console.exe'
$extMode=if($Biome -eq 'all'){'all-biomes'}else{'biome='+$Biome}
& $extEngine --path $extRoot -- $extMode
