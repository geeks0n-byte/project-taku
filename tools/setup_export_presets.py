"""Rebuild export_presets.cfg with AAB (Play) + APK (device deploy) presets."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CFG = ROOT / "export_presets.cfg"
EXAMPLE = ROOT / "export_presets.example.cfg"

EXCLUDE = (
    "addons/admob/gdscript/sample/*,addons/admob/csharp/*,addons/admob/skills/*,"
    "addons/admob/docs/*,dev/*,tools/*,tests/*,docs/*,**/*.xcf,**/*.py,**/*.md,"
    "__pycache__/*,addons/godot_ai/*,resources/background/boot_void*.png,"
    "resources/background/splash_void_icon.png,resources/icons/_godot_tile_raster/*,"
    "resources/localization/edit/*,_branch.txt"
)

WINDOWS_PRESET_BODY = '''
[preset.2]

name="Windows Desktop"
platform="Windows Desktop"
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="__EXCLUDE__"
export_path="../../Downloads/Spaceblox.exe"
patches=PackedStringArray()
patch_delta_encoding=false
patch_delta_compression_level_zstd=19
patch_delta_min_reduction=0.1
patch_delta_include_filters="*"
patch_delta_exclude_filters=""
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.2.options]

custom_template/debug=""
custom_template/release=""
debug/export_console_wrapper=1
binary_format/embed_pck=false
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
shader_baker/enabled=false
binary_format/architecture="x86_64"
codesign/enable=false
codesign/timestamp=true
codesign/timestamp_server_url=""
codesign/digest_algorithm=1
codesign/description=""
codesign/custom_options=PackedStringArray()
application/modify_resources=true
application/icon=""
application/console_wrapper_icon=""
application/icon_interpolation=4
application/file_version=""
application/product_version=""
application/company_name=""
application/product_name=""
application/file_description=""
application/copyright=""
application/trademarks=""
application/export_angle=0
application/export_d3d12=0
application/d3d12_agility_sdk_multiarch=true
ssh_remote_deploy/enabled=false
ssh_remote_deploy/host="user@host_ip"
ssh_remote_deploy/port="22"
ssh_remote_deploy/extra_args_ssh=""
ssh_remote_deploy/extra_args_scp=""
ssh_remote_deploy/run_script="Expand-Archive -LiteralPath '{temp_dir}\\{archive_name}' -DestinationPath '{temp_dir}'
$action = New-ScheduledTaskAction -Execute '{temp_dir}\\{exe_name}' -Argument '{cmd_args}'
$trigger = New-ScheduledTaskTrigger -Once -At 00:00
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings
Register-ScheduledTask godot_remote_debug -InputObject $task -Force:$true
Start-ScheduledTask -TaskName godot_remote_debug
while (Get-ScheduledTask -TaskName godot_remote_debug | ? State -eq running) { Start-Sleep -Milliseconds 100 }
Unregister-ScheduledTask -TaskName godot_remote_debug -Confirm:$false -ErrorAction:SilentlyContinue"
ssh_remote_deploy/cleanup_script="Stop-ScheduledTask -TaskName godot_remote_debug -ErrorAction:SilentlyContinue
Unregister-ScheduledTask -TaskName godot_remote_debug -Confirm:$false -ErrorAction:SilentlyContinue
Remove-Item -Recurse -Force '{temp_dir}'"
dotnet/include_scripts_content=false
dotnet/include_debug_symbols=false
dotnet/embed_build_outputs=false
'''


def _read_android_options(text: str) -> str:
    m = re.search(r"\[preset\.0\.options\]\n(.*)\Z", text, re.S)
    if not m:
        raise SystemExit("Could not parse preset.0.options from export_presets.cfg")
    opts = m.group(1).rstrip() + "\n"
    if "godot_play_game_services/game_id" not in opts:
        opts += 'godot_play_game_services/game_id=""\n'
    return opts


def _android_header(idx: int, name: str, export_path: str, export_format: int) -> str:
    return f'''[preset.{idx}]

name="{name}"
platform="Android"
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="{EXCLUDE}"
export_path="{export_path}"
patches=PackedStringArray()
patch_delta_encoding=false
patch_delta_compression_level_zstd=19
patch_delta_min_reduction=0.1
patch_delta_include_filters="*"
patch_delta_exclude_filters=""
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.{idx}.options]

'''


def _patch_options(opts: str, export_format: int) -> str:
    opts = re.sub(
        r"gradle_build/export_format=\d+",
        f"gradle_build/export_format={export_format}",
        opts,
        count=1,
    )
    return opts


def build_cfg(android_options: str) -> str:
    runnable = '''[runnable_presets]

Android="Android Device (APK)"
"Windows Desktop"="Windows Desktop"

'''
    aab = _android_header(0, "Android Play (AAB)", "../../Downloads/Spaceblox.aab", 1)
    aab += _patch_options(android_options, 1)
    apk = _android_header(1, "Android Device (APK)", "../../Downloads/Spaceblox.apk", 0)
    apk += _patch_options(android_options, 0)
    return runnable + aab + "\n" + apk + WINDOWS_PRESET_BODY.replace("__EXCLUDE__", EXCLUDE)


def main() -> None:
    if not CFG.is_file():
        raise SystemExit(f"Missing {CFG}")
    text = CFG.read_text(encoding="utf-8")
    opts = _read_android_options(text)
    out = build_cfg(opts)
    CFG.write_text(out, encoding="utf-8", newline="\n")
    EXAMPLE.write_text(out, encoding="utf-8", newline="\n")
    print(f"Wrote dual Android presets to {CFG} and {EXAMPLE}")


if __name__ == "__main__":
    main()
