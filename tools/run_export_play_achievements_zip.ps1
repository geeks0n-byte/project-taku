$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
python "$PSScriptRoot\export_play_achievements_zip.py"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
