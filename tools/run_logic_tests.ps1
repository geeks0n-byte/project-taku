# Runs headless puzzle logic tests with the local Godot 4.7.2 install.
param(
	[string]$GodotExe = "C:\Users\Giga\Desktop\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
& $GodotExe --headless --path $root -s "res://tests/run_logic_tests.gd"
exit $LASTEXITCODE
