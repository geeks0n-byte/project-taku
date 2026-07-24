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
@onready var sfx_btn: Button = $CenterContainer/OptionsPanel/VBoxContainer/SfxButton
@onready var privacy_btn: Button = $CenterContainer/OptionsPanel/VBoxContainer/PrivacyPolicyButton
@onready var del_save_btn: Button = $CenterContainer/OptionsPanel/VBoxContainer/DeleteSaveButton
@onready var del_custom_btn: Button = $CenterContainer/OptionsPanel/VBoxContainer/DeleteCustomButton
@onready var unlock_all_btn: Button = $CenterContainer/OptionsPanel/VBoxContainer/UnlockAllButton
@onready var close_btn: Button = $CenterContainer/OptionsPanel/VBoxContainer/CloseOptionsButton
@onready var status_label: Label = $CenterContainer/OptionsPanel/VBoxContainer/StatusLabel
@onready var _confirm_blocker: ColorRect = $ConfirmBlocker
@onready var _confirm_label: Label = $ConfirmBlocker/CenterContainer/Panel/VBoxContainer/PromptLabel
@onready var _confirm_yes_btn: Button = $ConfirmBlocker/CenterContainer/Panel/VBoxContainer/HBoxContainer/YesButton
@onready var _confirm_no_btn: Button = $ConfirmBlocker/CenterContainer/Panel/VBoxContainer/HBoxContainer/NoButton

var _pending_confirm: ConfirmAction = ConfirmAction.NONE
## Main-menu-only rows (reset progress + debug tools).
var _from_main_menu: bool = false
var _show_debug_options: bool = false

func _ready() -> void:
	if prev_btn:
		prev_btn.pressed.connect(_on_prev_lang)
	if next_btn:
		next_btn.pressed.connect(_on_next_lang)
	if bg_btn:
		bg_btn.pressed.connect(_on_toggle_background)
	if bgm_btn:
		bgm_btn.pressed.connect(_on_toggle_bgm)
	if sfx_btn:
		sfx_btn.pressed.connect(_on_toggle_sfx)
	if privacy_btn:
		privacy_btn.pressed.connect(_on_privacy_policy_pressed)
	if del_save_btn:
		del_save_btn.pressed.connect(_on_delete_save_pressed)
	if del_custom_btn:
		del_custom_btn.pressed.connect(_on_delete_custom_pressed)
	if unlock_all_btn:
		unlock_all_btn.pressed.connect(_on_unlock_all_pressed)
	if close_btn:
		close_btn.pressed.connect(hide_menu)
	_setup_confirm_panel()
	_configure_main_menu_buttons()
	_mount_header()
	_update_lang_label()
	_update_background_label()
	_update_bgm_label()
	_update_sfx_label()
	_fit_option_buttons()
	_position_close_button()

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
	title_label.set_meta("_screen_header_font_size", 72)
	title_label.set_meta("_screen_header_outline", GameConstants.SCREEN_HEADER_OUTLINE)
	HudLayout.mount_screen_header(host, title_label)
	var center := get_node_or_null("CenterContainer") as Control
	if center:
		# Extra gap so option rows clear the OPTIONS header (includes SFX row).
		HudLayout.pin_menu_body_below_header(center, 1100.0, 120.0)

func show_menu(from_main_menu: bool = false) -> void:
	_from_main_menu = from_main_menu
	_show_debug_options = from_main_menu and GlobalGameManager.debug_tools_enabled
	_configure_main_menu_buttons()
	_update_lang_label()
	_update_background_label()
	_update_bgm_label()
	_update_sfx_label()
	_fit_option_buttons()
	if status_label:
		status_label.text = ""
	_hide_confirm()
	visible = true

func hide_menu() -> void:
	_hide_confirm()
	visible = false
	back_requested.emit()

func _configure_main_menu_buttons() -> void:
	if del_save_btn:
		del_save_btn.visible = _from_main_menu
		if _from_main_menu:
			del_save_btn.text = "UI_RESET_PROGRESS"
			del_save_btn.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	var show_debug := _show_debug_options
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
		title_label.set_meta("_screen_header_font_size", 72)
		title_label.set_meta("_screen_header_outline", GameConstants.SCREEN_HEADER_OUTLINE)
		HudLayout.apply_screen_header_style(title_label)
	if privacy_btn:
		privacy_btn.text = tr("UI_PRIVACY_POLICY")
	for btn in [del_save_btn, bg_btn, bgm_btn, sfx_btn, privacy_btn, del_custom_btn, unlock_all_btn]:
		_apply_option_button(btn)
	_position_close_button()
	HudLayout.apply_secondary_button(close_btn)
	# Language arrows keep tile chrome.
	if prev_btn:
		prev_btn.custom_minimum_size = Vector2(100, 100)
		prev_btn.flat = false
		_apply_button_tile_styles(prev_btn)
		prev_btn.add_theme_constant_override("outline_size", GameConstants.MENU_TEXT_OUTLINE)
		HudLayout.fit_text_button(
			prev_btn, GameConstants.UI_BTN_PRIMARY_FONT, GameConstants.UI_BTN_PRIMARY_FONT_MIN
		)
	if next_btn:
		next_btn.custom_minimum_size = Vector2(100, 100)
		next_btn.flat = false
		_apply_button_tile_styles(next_btn)
		next_btn.add_theme_constant_override("outline_size", GameConstants.MENU_TEXT_OUTLINE)
		HudLayout.fit_text_button(
			next_btn, GameConstants.UI_BTN_PRIMARY_FONT, GameConstants.UI_BTN_PRIMARY_FONT_MIN
		)
	_update_lang_label()
	_refresh_confirm_texts()

## Option rows with the shared gray tile button art; size follows caption text.
func _apply_option_button(button: Button) -> void:
	if not button or not button.visible:
		return
	button.flat = false
	_apply_button_tile_styles(button)
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	button.add_theme_constant_override("outline_size", GameConstants.MENU_TEXT_OUTLINE)
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.clip_text = false
	HudLayout.apply_locale_font_to_control(button)
	var font_size := HudLayout.scaled_font_size(GameConstants.UI_BTN_PRIMARY_FONT)
	button.add_theme_font_size_override("font_size", font_size)
	var display := _option_button_display_text(button)
	var font: Font = (
		ThemeDB.fallback_font if button.get_meta("_use_default_font", false) else HudLayout.ui_font()
	)
	if font == null:
		font = ThemeDB.fallback_font
	var measured := font.get_string_size(display, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var pad_x := 56.0 + float(GameConstants.MENU_TEXT_OUTLINE)
	var pad_y := 48.0 + float(GameConstants.MENU_TEXT_OUTLINE)
	button.custom_minimum_size = Vector2(
		maxf(220.0, measured.x + pad_x),
		maxf(100.0, measured.y + pad_y)
	)

func _option_button_display_text(button: Button) -> String:
	if button == null:
		return ""
	var host := button.get_node_or_null("ToggleCaptionHost") as Control
	if host:
		var caption := host.get_node_or_null("ToggleCaption") as RichTextLabel
		if caption and not caption.get_parsed_text().is_empty():
			return caption.get_parsed_text().strip_edges()
	var raw := button.text
	if raw.is_empty():
		return ""
	if button.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED:
		return String(TranslationServer.translate(raw))
	return raw

func _apply_button_tile_styles(button: Button) -> void:
	if not button:
		return
	var tex := preload("res://resources/buttons/button_tile_gray_dark.svg") as Texture2D
	for style_name in ["normal", "pressed", "hover", "disabled", "focus"]:
		var box := StyleBoxTexture.new()
		box.texture = tex
		box.texture_margin_left = 16.0
		box.texture_margin_top = 16.0
		box.texture_margin_right = 16.0
		box.texture_margin_bottom = 16.0
		box.content_margin_left = 8.0
		box.content_margin_top = 8.0
		box.content_margin_right = 8.0
		box.content_margin_bottom = 8.0
		if style_name == "hover":
			box.modulate_color = Color(1.2, 1.2, 1.2, 1.0)
		elif style_name == "pressed":
			box.modulate_color = Color(0.8, 0.8, 0.8, 1.0)
		elif style_name == "disabled":
			box.modulate_color = Color(0.55, 0.55, 0.55, 1.0)
		button.add_theme_stylebox_override(style_name, box)

func _position_close_button() -> void:
	if close_btn == null:
		return
	# OptionsMenu is a CanvasLayer — Close must live on a Control host.
	var host := get_node_or_null("CloseButtonHost") as Control
	if host == null:
		host = Control.new()
		host.name = "CloseButtonHost"
		host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(host)
	if close_btn.get_parent() != host:
		var old := close_btn.get_parent()
		if old:
			old.remove_child(close_btn)
		host.add_child(close_btn)
	close_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	var half_w := GameConstants.UI_BTN_SECONDARY_SIZE.x * 0.5
	close_btn.offset_left = -half_w
	close_btn.offset_right = half_w
	close_btn.offset_top = GameConstants.SCREEN_BOTTOM_NAV_TOP
	close_btn.offset_bottom = GameConstants.SCREEN_BOTTOM_NAV_BOTTOM
	close_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	close_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP

const _TOGGLE_ACCENT := Color(1.0, 0.84, 0.0, 1.0)

func _set_toggle_button_caption(button: Button, full_text: String) -> void:
	if not button:
		return
	button.text = ""
	# Remove legacy full-rect caption from earlier layout.
	var legacy := button.get_node_or_null("ToggleCaption")
	if legacy:
		legacy.queue_free()
	var host := button.get_node_or_null("ToggleCaptionHost") as CenterContainer
	if host == null:
		host = CenterContainer.new()
		host.name = "ToggleCaptionHost"
		host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		host.offset_left = 12.0
		host.offset_top = 8.0
		host.offset_right = -12.0
		host.offset_bottom = -8.0
		button.add_child(host)
	var caption := host.get_node_or_null("ToggleCaption") as RichTextLabel
	if caption == null:
		caption = RichTextLabel.new()
		caption.name = "ToggleCaption"
		caption.bbcode_enabled = true
		caption.fit_content = true
		caption.scroll_active = false
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.autowrap_mode = TextServer.AUTOWRAP_OFF
		caption.add_theme_color_override("default_color", Color.WHITE)
		caption.add_theme_color_override("font_outline_color", Color.BLACK)
		caption.add_theme_constant_override("outline_size", GameConstants.MENU_TEXT_OUTLINE)
		host.add_child(caption)
	# Keep caption above the tile chrome.
	button.move_child(host, -1)
	HudLayout.apply_locale_font_to_control(caption)
	var font_size := HudLayout.scaled_font_size(GameConstants.UI_BTN_PRIMARY_FONT)
	caption.add_theme_font_size_override("normal_font_size", font_size)
	# Highlight ON / OFF / DYNAMIC / STATIC (and locale equivalents) in gold.
	var accent := _TOGGLE_ACCENT.to_html(false)
	var tokens: Array[String] = [
		"DYNAMICZNE", "STATYCZNE", "DYNAMISCH", "STATISCH", "DYNAMIQUE", "STATIQUE",
		"DINÁMICO", "ESTÁTICO", "დინამიკური", "სტატიკური", "ДИНАМІЧНИЙ", "СТАТИЧНИЙ",
		"DYNAMIC", "STATIC", "УВІМК.", "ВИМК.", "ჩართ.", "გამორთ.", "WŁ.", "WYŁ.",
		"OUI", "NON", "SÍ", "ON", "OFF", "AN", "AUS", "NO",
	]
	var colored := full_text
	for token in tokens:
		if colored.contains(token):
			colored = colored.replace(token, "[color=#%s]%s[/color]" % [accent, token])
			break
	caption.text = "[center]%s[/center]" % colored
	# Resize tile to the new caption immediately.
	_apply_option_button(button)

func _update_background_label() -> void:
	if not bg_btn:
		return
	var key := "UI_BG_STATIC" if SaveManager.background_static else "UI_BG_DYNAMIC"
	_set_toggle_button_caption(bg_btn, tr(key))

func _update_bgm_label() -> void:
	if not bgm_btn:
		return
	_set_toggle_button_caption(bgm_btn, tr("UI_BGM_ON" if SaveManager.bgm_enabled else "UI_BGM_OFF"))

func _update_sfx_label() -> void:
	if not sfx_btn:
		return
	_set_toggle_button_caption(sfx_btn, tr("UI_SFX_ON" if SaveManager.sfx_enabled else "UI_SFX_OFF"))

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
	_update_sfx_label()
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
	_update_sfx_label()
	_fit_option_buttons()

func _on_toggle_background() -> void:
	SaveManager.set_background_static(not SaveManager.background_static)
	_update_background_label()

func _on_toggle_bgm() -> void:
	SaveManager.set_bgm_enabled(not SaveManager.bgm_enabled)
	_update_bgm_label()

func _on_toggle_sfx() -> void:
	SaveManager.set_sfx_enabled(not SaveManager.sfx_enabled)
	_update_sfx_label()

func _on_privacy_policy_pressed() -> void:
	if AdsManager:
		AdsManager.open_privacy_policy()
	else:
		OS.shell_open("https://spaceblox.game/privacy")

func _setup_confirm_panel() -> void:
	if _confirm_blocker:
		_confirm_blocker.visible = false
		_confirm_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := _confirm_blocker.get_node_or_null("CenterContainer/Panel") as Panel if _confirm_blocker else null
	if panel:
		panel.add_theme_stylebox_override("panel", HudLayout.make_dialog_panel_style())
	if _confirm_yes_btn and not _confirm_yes_btn.pressed.is_connected(_on_confirm_yes):
		_confirm_yes_btn.pressed.connect(_on_confirm_yes)
	if _confirm_no_btn and not _confirm_no_btn.pressed.is_connected(_hide_confirm):
		_confirm_no_btn.pressed.connect(_hide_confirm)
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
	target.add_theme_constant_override("outline_size", GameConstants.MENU_TEXT_OUTLINE)

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
