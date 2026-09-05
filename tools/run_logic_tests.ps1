# Runs headless puzzle logic tests.
# Godot path: GODOT_EXE, PATH, .godot-ci cache, or -AllowDownload / GODOT_ALLOW_DOWNLOAD=1.
param(
	[string]$GodotExe = "",
	[switch]$AllowDownload
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\resolve_godot.ps1"

$resolved = Resolve-GodotExecutable -ExplicitPath $GodotExe -AllowDownload:$AllowDownload
$root = Split-Path -Parent $PSScriptRoot

& $resolved --headless --path $root -s "res://tests/run_logic_tests.gd"
exit $LASTEXITCODE
