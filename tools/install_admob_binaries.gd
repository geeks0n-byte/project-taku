extends SceneTree

## Headless helper: download AdMob Android/iOS native binaries if missing.
func _init() -> void:
	const BinaryInstaller := preload(
		"res://addons/admob/internal/services/network/binary_installer.gd"
	)
	BinaryInstaller.install_missing_binaries_sync()
	quit(0)
