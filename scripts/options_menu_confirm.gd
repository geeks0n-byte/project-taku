class_name OptionsMenuConfirm
extends RefCounted

enum Action {
	NONE,
	RESET_PROGRESS,
	DELETE_CUSTOM,
	UNLOCK_ALL,
	UNLOCK_ALL_ACHIEVEMENTS,
	CLOUD_SYNC_CHOICE,
}

var _blocker: ColorRect
var _label: Label
var _yes_btn: Button
var _no_btn: Button
var _set_chrome_visible: Callable
var _copy_button_styles: Callable
var _on_reset_progress: Callable
var _on_delete_custom: Callable
var _on_unlock_all: Callable
var _on_unlock_achievements: Callable

var pending: Action = Action.NONE
var cloud_local_summary: Dictionary = {}
var cloud_remote_summary: Dictionary = {}


func setup(
	blocker: ColorRect,
	label: Label,
	yes_btn: Button,
	no_btn: Button,
	set_chrome_visible: Callable,
	copy_button_styles: Callable,
	on_reset_progress: Callable,
	on_delete_custom: Callable,
	on_unlock_all: Callable,
	on_unlock_achievements: Callable
) -> void:
	_blocker = blocker
	_label = label
	_yes_btn = yes_btn
	_no_btn = no_btn
	_set_chrome_visible = set_chrome_visible
	_copy_button_styles = copy_button_styles
	_on_reset_progress = on_reset_progress
	_on_delete_custom = on_delete_custom
	_on_unlock_all = on_unlock_all
	_on_unlock_achievements = on_unlock_achievements


func setup_panel() -> void:
	if _blocker:
		_blocker.visible = false
		_blocker.color = Color(0, 0, 0, 0)
		HudLayout.register_modal_blocker(_blocker)
	var center := _blocker.get_node_or_null("CenterContainer") as Control if _blocker else null
	if center:
		HudLayout.raise_centered_dialog_host(center)
	var panel := _blocker.get_node_or_null("CenterContainer/Panel") as Panel if _blocker else null
	if panel:
		panel.add_theme_stylebox_override("panel", HudLayout.make_dialog_panel_style())
	if _yes_btn and not _yes_btn.pressed.is_connected(_on_yes):
		_yes_btn.pressed.connect(_on_yes)
	if _no_btn and not _no_btn.pressed.is_connected(_on_no):
		_no_btn.pressed.connect(_on_no)
	if _yes_btn:
		_yes_btn.set_meta("_tr_key", "UI_YES")
	if _no_btn:
		_no_btn.set_meta("_tr_key", "UI_NO")
	if _copy_button_styles.is_valid():
		_copy_button_styles.call(_yes_btn)
		_copy_button_styles.call(_no_btn)
	refresh_texts()


func is_visible() -> bool:
	return _blocker != null and _blocker.visible


func show_for_action(action: Action, message: String = "") -> void:
	pending = action
	cloud_local_summary = {}
	cloud_remote_summary = {}
	if _label:
		_label.text = message
	refresh_texts()
	var panel := _blocker.get_node_or_null("CenterContainer/Panel") as Panel if _blocker else null
	if panel:
		HudLayout.fit_dialog_panel(panel, HudLayout.UI_DEFAULT_DIALOG_WIDTH)
	if _set_chrome_visible.is_valid():
		_set_chrome_visible.call(false)
	if _blocker:
		_blocker.color = Color(0, 0, 0, 0)
		_blocker.visible = true


func show_cloud_choice(message: String, local_summary: Dictionary, remote_summary: Dictionary) -> void:
	cloud_local_summary = local_summary
	cloud_remote_summary = remote_summary
	show_for_action(Action.CLOUD_SYNC_CHOICE, message)


func hide() -> void:
	if pending == Action.CLOUD_SYNC_CHOICE and CloudSaveManager and CloudSaveManager.is_syncing:
		CloudSaveManager.resolve_sync_choice(false)
	_dismiss_panel()


func _dismiss_panel() -> void:
	pending = Action.NONE
	cloud_local_summary = {}
	cloud_remote_summary = {}
	if _blocker:
		_blocker.visible = false
	if _set_chrome_visible.is_valid():
		_set_chrome_visible.call(true)


func refresh_texts() -> void:
	if _yes_btn:
		var yes_key := "UI_CLOUD_KEEP_CLOUD" if pending == Action.CLOUD_SYNC_CHOICE else "UI_YES"
		var yes_text := tr(yes_key)
		_yes_btn.text = yes_text
		HudLayout.apply_dialog_button(_yes_btn, yes_text)
	if _no_btn:
		var no_key := "UI_CLOUD_KEEP_DEVICE" if pending == Action.CLOUD_SYNC_CHOICE else "UI_NO"
		var no_text := tr(no_key)
		_no_btn.text = no_text
		HudLayout.apply_dialog_button(_no_btn, no_text)
	if _label:
		match pending:
			Action.RESET_PROGRESS:
				_label.text = tr("UI_CONFIRM_RESET_PROGRESS")
			Action.DELETE_CUSTOM:
				_label.text = tr("UI_CONFIRM_DELETE_CUSTOM")
			Action.UNLOCK_ALL:
				_label.text = tr("UI_CONFIRM_UNLOCK_ALL")
			Action.UNLOCK_ALL_ACHIEVEMENTS:
				_label.text = tr("UI_CONFIRM_UNLOCK_ACHIEVEMENTS")
			Action.CLOUD_SYNC_CHOICE:
				pass
			_:
				if _label.text.is_empty():
					_label.text = tr("UI_CONFIRM_RESET_PROGRESS")
		var prompt_color := (
			Color(0.45, 1.0, 0.45)
			if (
				pending == Action.UNLOCK_ALL
				or pending == Action.UNLOCK_ALL_ACHIEVEMENTS
			)
			else Color(1.0, 0.45, 0.45)
		)
		_label.add_theme_color_override("font_color", prompt_color)
		HudLayout.apply_popup_label(_label, GameConstants.UI_BODY_FONT_SIZE_LARGE)
	if _blocker and _blocker.visible:
		var panel := _blocker.get_node_or_null("CenterContainer/Panel") as Panel
		if panel:
			HudLayout.fit_dialog_panel(panel, HudLayout.UI_DEFAULT_DIALOG_WIDTH)
	apply_a11y_labels()


func apply_a11y_labels() -> void:
	if _label and _blocker and _blocker.visible:
		_label.accessibility_name = String(_label.text).strip_edges()
	if _yes_btn:
		_yes_btn.accessibility_name = String(_yes_btn.text).strip_edges()
	if _no_btn:
		_no_btn.accessibility_name = String(_no_btn.text).strip_edges()


func _on_no() -> void:
	if pending == Action.CLOUD_SYNC_CHOICE and CloudSaveManager:
		CloudSaveManager.resolve_sync_choice(false)
	_dismiss_panel()


func _on_yes() -> void:
	var action := pending
	if action == Action.CLOUD_SYNC_CHOICE:
		if CloudSaveManager:
			CloudSaveManager.resolve_sync_choice(true)
		_dismiss_panel()
		return
	_dismiss_panel()
	match action:
		Action.RESET_PROGRESS:
			if _on_reset_progress.is_valid():
				_on_reset_progress.call()
		Action.DELETE_CUSTOM:
			if _on_delete_custom.is_valid():
				_on_delete_custom.call()
		Action.UNLOCK_ALL:
			if _on_unlock_all.is_valid():
				_on_unlock_all.call()
		Action.UNLOCK_ALL_ACHIEVEMENTS:
			if _on_unlock_achievements.is_valid():
				_on_unlock_achievements.call()
