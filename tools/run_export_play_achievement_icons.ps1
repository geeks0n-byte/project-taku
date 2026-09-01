$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot\resolve_godot.ps1"
$godot = Resolve-GodotExecutable
& $godot --headless --path $root -s res://tools/export_play_achievement_icons.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
