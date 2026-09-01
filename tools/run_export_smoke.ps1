# Runs headless Android export preset smoke checks.
param(
	[string]$GodotExe = "",
	[switch]$AllowDownload
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\resolve_godot.ps1"

$resolved = Resolve-GodotExecutable -ExplicitPath $GodotExe -AllowDownload:$AllowDownload
$root = Split-Path -Parent $PSScriptRoot

& $resolved --headless --path $root -s "res://tests/run_export_smoke.gd"
exit $LASTEXITCODE
