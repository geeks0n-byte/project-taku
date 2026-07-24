extends CanvasLayer

signal save_deleted
signal back_requested

const LANGUAGES = ["en", "es", "de", "fr", "pl", "ka", "uk"]
const LANG_NAMES = ["ENGLISH", "ESPAÑOL", "DEUTSCH", "FRANÇAIS", "POLSKI", "ქართული", "УКРАЇНСЬКА"]

enum ConfirmAction { NONE, RESET_PROGRESS, DELETE_CUSTOM }

@onready var title_label: Label = $CenterContainer/OptionsPanel/VBoxContainer/TitleLabel
@onready var lang_label: Label = $CenterContainer/OptionsPanel/VBoxContainer/LanguageContainer/LanguageLabel
@onready var prev_btn: Button = $CenterContainer/OptionsPanel/VBoxContainer/LanguageContainer/PrevLangButton
@onready var next_btn: Button = $CenterContainer/OptionsPanel/VBoxContainer/LanguageContainer/NextLangButton
@onready var bg_btn: Button = $CenterContainer/OptionsPanel/VBoxContainer/BackgroundButton
@onready var bgm_btn: Button = $CenterContainer/OptionsPanel/VBoxContainer/BgmButton
@onready var del_save_btn: Button = $CenterContainer/OptionsPanel/VBoxContainer/DeleteSaveButton
@onready var del_custom_btn: Button = $CenterContainer/OptionsPanel/VBoxContainer/DeleteCustomButton
@onready var unlock_all_btn: Button = $CenterContainer/OptionsPanel/VBoxContainer/UnlockAllButton
@onready var close_btn: Button = $CenterContainer/OptionsPanel/VBoxContainer/CloseOptionsButton
@onready var status_label: Label = $CenterContainer/OptionsPanel/VBoxContainer/StatusLabel

var _pending_confirm: ConfirmAction = ConfirmAction.NONE
var _confirm_blocker: ColorRect
var _confirm_label: Label
var _confirm_yes_btn: Button
var _confirm_no_btn: Button

func _ready() -> void:
	if prev_btn:
		prev_btn.pressed.connect(_on_prev_lang)
	if next_btn:
		next_btn.pressed.connect(_on_next_lang)
	if bg_btn:
		bg_btn.pressed.connect(_on_toggle_background)
	if bgm_btn:
		bgm_btn.pressed.connect(_on_toggle_bgm)
	if del_save_btn:
		del_save_btn.pressed.connect(_on_delete_save_pressed)
	if del_custom_btn:
		del_custom_btn.pressed.connect(_on_delete_custom_pressed)
	if unlock_all_btn:
		unlock_all_btn.pressed.connect(_on_unlock_all_pressed)
	if close_btn:
		close_btn.pressed.connect(hide_menu)
	_build_confirm_panel()
	_configure_debug_buttons()
	_mount_header()
	_update_lang_label()
	_update_background_label()
	_update_bgm_label()
	_fit_option_buttons()

func _mount_header() -> void:
	if not title_label:
		return
	var host := get_node_or_null("ScreenHeaderHost") as Control
	if host == null:
		host = Control.new()
		host.name = "ScreenHeaderHost"
		host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(host)
		move_child(host, 0)
	HudLayout.mount_screen_header(host, title_label)
	var center := get_node_or_null("CenterContainer") as Control
	if center:
		# Extra gap so option rows clear the OPTIONS header.
		HudLayout.pin_menu_body_below_header(center, 980.0, 56.0)
func show_menu() -> void:
	_configure_debug_buttons()
	_update_lang_label()
	_update_background_label()
	_update_bgm_label()
	_fit_option_buttons()
	if status_label:
		status_label.text = ""
	_hide_confirm()
	visible = true

func hide_menu() -> void:
	_hide_confirm()
	visible = false
	back_requested.emit()

func _configure_debug_buttons() -> void:
	var show_debug := GlobalGameManager.debug_tools_enabled
	if del_custom_btn:
		del_custom_btn.visible = show_debug
		if show_debug:
			del_custom_btn.text = "UI_DELETE_CUSTOM"
			del_custom_btn.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	if unlock_all_btn:
		unlock_all_btn.visible = show_debug
		if show_debug:
			unlock_all_btn.text = "UI_UNLOCK_ALL_LEVELS"
			unlock_all_btn.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS

func _update_lang_label() -> void:
	if not lang_label:
		return
	var current_locale = TranslationServer.get_locale().substr(0, 2)
	var idx = LANGUAGES.find(current_locale)
	if idx == -1:
		idx = 0
	lang_label.text = LANG_NAMES[idx]
	# ENGLISH keeps the pixel font; other language names need default font coverage.
	if current_locale == "en":
		lang_label.add_theme_font_override("font", HudLayout.PIXEL_FONT)
	else:
		lang_label.add_theme_font_override("font", ThemeDB.fallback_font)
	lang_label.add_theme_font_size_override(
		"font_size", HudLayout.scaled_font_size(GameConstants.UI_BODY_FONT_SIZE_LARGE)
	)
	lang_label.custom_minimum_size = Vector2(380, GameConstants.UI_BTN_PRIMARY_SIZE.y)

func _fit_option_buttons() -> void:
	if title_label:
		HudLayout.apply_screen_header_style(title_label)
	for btn in [del_save_btn, bg_btn, bgm_btn]:
		HudLayout.apply_primary_button(btn)
	if del_custom_btn and del_custom_btn.visible:
		HudLayout.apply_primary_button(del_custom_btn)
	if unlock_all_btn and unlock_all_btn.visible:
		HudLayout.apply_primary_button(unlock_all_btn)
	HudLayout.apply_secondary_button(close_btn)
	# Language arrows stay square and compact.
	if prev_btn:
		prev_btn.custom_minimum_size = Vector2(100, 100)
		HudLayout.fit_text_button(
			prev_btn, GameConstants.UI_BTN_PRIMARY_FONT, GameConstants.UI_BTN_PRIMARY_FONT_MIN
		)
	if next_btn:
		next_btn.custom_minimum_size = Vector2(100, 100)
		HudLayout.fit_text_button(
			next_btn, GameConstants.UI_BTN_PRIMARY_FONT, GameConstants.UI_BTN_PRIMARY_FONT_MIN
		)
	_update_lang_label()
	_refresh_confirm_texts()

func _update_background_label() -> void:
	if not bg_btn:
		return
	bg_btn.text = "UI_BG_STATIC" if SaveManager.background_static else "UI_BG_DYNAMIC"
	# Force refresh of auto-translated text by reassigning.
	bg_btn.text = tr("UI_BG_STATIC" if SaveManager.background_static else "UI_BG_DYNAMIC")
	HudLayout.apply_primary_button(bg_btn)

func _on_prev_lang() -> void:
	var current_locale = TranslationServer.get_locale().substr(0, 2)
	var idx = LANGUAGES.find(current_locale)
	if idx == -1:
		idx = 0
	idx = (idx - 1 + LANGUAGES.size()) % LANGUAGES.size()
	SaveManager.set_language(LANGUAGES[idx])
	_update_lang_label()
	_update_background_label()
	_update_bgm_label()
	_fit_option_buttons()

func _on_next_lang() -> void:
	var current_locale = TranslationServer.get_locale().substr(0, 2)
	var idx = LANGUAGES.find(current_locale)
	if idx == -1:
		idx = 0
	idx = (idx + 1) % LANGUAGES.size()
	SaveManager.set_language(LANGUAGES[idx])
	_update_lang_label()
	_update_background_label()
	_update_bgm_label()
	_fit_option_buttons()

func _on_toggle_background() -> void:
	SaveManager.set_background_static(not SaveManager.background_static)
	_update_background_label()

func _update_bgm_label() -> void:
	if not bgm_btn:
		return
	bgm_btn.text = tr("UI_BGM_ON" if SaveManager.bgm_enabled else "UI_BGM_OFF")
	HudLayout.apply_primary_button(bgm_btn)

func _on_toggle_bgm() -> void:
	SaveManager.set_bgm_enabled(not SaveManager.bgm_enabled)
	_update_bgm_label()

func _build_confirm_panel() -> void:
	_confirm_blocker = ColorRect.new()
	_confirm_blocker.name = "ConfirmBlocker"
	_confirm_blocker.color = Color(0, 0, 0, 0.72)
	_confirm_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_blocker.visible = false
	add_child(_confirm_blocker)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_blocker.add_child(center)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(640, 360)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.12, 1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 36.0
	vbox.offset_top = 36.0
	vbox.offset_right = -36.0
	vbox.offset_bottom = -36.0
	vbox.add_theme_constant_override("separation", 28)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	_confirm_label = Label.new()
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_confirm_label.add_theme_color_override("font_color", Color(1, 0.45, 0.45, 1))
	_confirm_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_confirm_label.add_theme_constant_override("outline_size", 8)
	HudLayout.apply_popup_label(_confirm_label, GameConstants.UI_BODY_FONT_SIZE_LARGE)
	vbox.add_child(_confirm_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	vbox.add_child(row)

	_confirm_yes_btn = Button.new()
	_confirm_yes_btn.pressed.connect(_on_confirm_yes)
	row.add_child(_confirm_yes_btn)

	_confirm_no_btn = Button.new()
	_confirm_no_btn.pressed.connect(_hide_confirm)
	row.add_child(_confirm_no_btn)

	_copy_button_styles(_confirm_yes_btn)
	_copy_button_styles(_confirm_no_btn)
	_refresh_confirm_texts()

func _copy_button_styles(target: Button) -> void:
	var source := close_btn if close_btn else del_save_btn
	if not source or not target:
		return
	for style_name in ["normal", "pressed", "hover", "disabled"]:
		var style := source.get_theme_stylebox(style_name)
		if style:
			target.add_theme_stylebox_override(style_name, style)
	target.add_theme_color_override("font_outline_color", Color.BLACK)
	target.add_theme_constant_override("outline_size", 6)

func _refresh_confirm_texts() -> void:
	if _confirm_yes_btn:
		_confirm_yes_btn.text = tr("UI_YES")
		HudLayout.apply_dialog_button(_confirm_yes_btn)
	if _confirm_no_btn:
		_confirm_no_btn.text = tr("UI_NO")
		HudLayout.apply_dialog_button(_confirm_no_btn)
	if _confirm_label:
		HudLayout.apply_popup_label(_confirm_label, GameConstants.UI_BODY_FONT_SIZE_LARGE)
		match _pending_confirm:
			ConfirmAction.RESET_PROGRESS:
				_confirm_label.text = tr("CONFIRM_RESET_PROGRESS")
			ConfirmAction.DELETE_CUSTOM:
				_confirm_label.text = tr("CONFIRM_DELETE_CUSTOM")

func _show_confirm(action: ConfirmAction, message: String) -> void:
	_pending_confirm = action
	if _confirm_label:
		_confirm_label.text = message
	_refresh_confirm_texts()
	if _confirm_blocker:
		_confirm_blocker.visible = true

func _hide_confirm() -> void:
	_pending_confirm = ConfirmAction.NONE
	if _confirm_blocker:
		_confirm_blocker.visible = false

func _on_confirm_yes() -> void:
	var action := _pending_confirm
	_hide_confirm()
	match action:
		ConfirmAction.RESET_PROGRESS:
			_do_delete_save()
		ConfirmAction.DELETE_CUSTOM:
			_do_delete_custom()

func _on_delete_save_pressed() -> void:
	_show_confirm(ConfirmAction.RESET_PROGRESS, tr("CONFIRM_RESET_PROGRESS"))

func _on_delete_custom_pressed() -> void:
	_show_confirm(ConfirmAction.DELETE_CUSTOM, tr("CONFIRM_DELETE_CUSTOM"))

func _on_unlock_all_pressed() -> void:
	SaveManager.unlock_all_levels()
	if status_label:
		status_label.text = tr("UNLOCK_ALL_DONE")
		status_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
		status_label.modulate = Color(0.45, 1.0, 0.45)
		HudLayout.apply_body_label(status_label, GameConstants.UI_BODY_FONT_SIZE)

func _do_delete_save() -> void:
	SaveManager.delete_save_file()
	if status_label:
		status_label.text = ""
	save_deleted.emit()

func _do_delete_custom() -> void:
	if DirAccess.dir_exists_absolute(GameConstants.DEV_LEVELS_DIR):
		var dir = DirAccess.open(GameConstants.DEV_LEVELS_DIR)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir() and (file_name.ends_with(".tres") or file_name.ends_with(".remap")):
					DirAccess.remove_absolute(GameConstants.DEV_LEVELS_DIR + file_name)
				file_name = dir.get_next()
			dir.list_dir_end()
	if status_label:
		status_label.text = tr("CUSTOM_DELETED")
		status_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
		status_label.modulate = Color(1.0, 0.84, 0.0)
		HudLayout.apply_body_label(status_label, GameConstants.UI_BODY_FONT_SIZE)
