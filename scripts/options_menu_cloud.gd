class_name OptionsMenuCloud
extends RefCounted

var _cloud_btn: Button
var _show_confirm: Callable
var _show_status: Callable


func setup(cloud_btn: Button, show_confirm: Callable, show_status: Callable) -> void:
	_cloud_btn = cloud_btn
	_show_confirm = show_confirm
	_show_status = show_status


func bind_manager() -> void:
	if CloudSaveManager == null:
		return
	if not CloudSaveManager.signed_in_changed.is_connected(_update_button):
		CloudSaveManager.signed_in_changed.connect(_update_button)
	if not CloudSaveManager.sync_started.is_connected(_update_button):
		CloudSaveManager.sync_started.connect(_update_button)
	if not CloudSaveManager.sync_finished.is_connected(_on_sync_finished):
		CloudSaveManager.sync_finished.connect(_on_sync_finished)
	if not CloudSaveManager.sync_needs_choice.is_connected(_on_sync_needs_choice):
		CloudSaveManager.sync_needs_choice.connect(_on_sync_needs_choice)


func on_pressed() -> void:
	if CloudSaveManager == null:
		return
	if CloudSaveManager.is_syncing:
		return
	if CloudSaveManager.is_stub():
		if CloudSaveManager.is_play_games_available():
			CloudSaveManager.sync_now()
		_update_button()
		return
	if not CloudSaveManager.is_signed_in:
		CloudSaveManager.sign_in()
	else:
		CloudSaveManager.sync_now()
	_update_button()


func update_button() -> void:
	_update_button()


func _update_button() -> void:
	if _cloud_btn == null:
		return
	var stub := CloudSaveManager == null or CloudSaveManager.is_stub()
	var plugin_installed := CloudSaveManager != null and CloudSaveManager.is_play_games_available()
	var syncing := CloudSaveManager != null and CloudSaveManager.is_syncing
	var key := "UI_CLOUD_PLAY_GAMES_NEEDED"
	if plugin_installed:
		if syncing:
			key = "UI_CLOUD_SYNCING"
		elif stub:
			key = "UI_CLOUD_SYNC"
		else:
			var signed_in := CloudSaveManager.is_signed_in
			key = "UI_CLOUD_SYNC" if signed_in else "UI_CLOUD_SIGN_IN"
	_cloud_btn.disabled = not plugin_installed or syncing
	_cloud_btn.text = key
	_cloud_btn.set_meta("_tr_key", key)
	_cloud_btn.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	_cloud_btn.modulate = Color(0.55, 0.55, 0.55, 1.0) if stub else Color.WHITE


func _on_sync_finished(ok: bool, _message: String) -> void:
	_update_button()
	if not _show_status.is_valid():
		return
	if ok:
		_show_status.call(tr("UI_CLOUD_SYNC_OK"), Color(0.45, 1.0, 0.45))
	elif CloudSaveManager != null and not CloudSaveManager.last_error.is_empty():
		_show_status.call(CloudSaveManager.last_error, Color(1.0, 0.45, 0.45))
	else:
		_show_status.call(tr("UI_CLOUD_SYNC_FAIL"), Color(1.0, 0.35, 0.35))


func _on_sync_needs_choice(local_summary: Dictionary, remote_summary: Dictionary) -> void:
	if not _show_confirm.is_valid():
		return
	var local_level := int(local_summary.get("max_level", 0))
	var local_stars := int(local_summary.get("star_total", 0))
	var remote_level := int(remote_summary.get("max_level", 0))
	var remote_stars := int(remote_summary.get("star_total", 0))
	var message := tr("UI_CLOUD_SYNC_CHOICE") % [
		local_level, local_stars, remote_level, remote_stars
	]
	_show_confirm.call(message, local_summary, remote_summary)
