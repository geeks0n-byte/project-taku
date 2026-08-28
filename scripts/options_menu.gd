# Options/settings overlay that handles language, audio, haptic toggles,
# privacy links, and destructive actions (reset progress, delete custom levels).
extends CanvasLayer

# Emitted after the save file is erased so the main menu can reset its state.
signal save_deleted
# Emitted when the menu is closed so the caller can restore the previous screen.
signal back_requested

# Locale codes and matching display names kept in parallel arrays for the language picker.
# Display names are intentionally never translated — they always appear in their own script.
const LANGUAGES = ["en", "es", "de", "fr", "pl", "ka", "uk"]
const LANG_NAMES = ["ENGLISH", "ESPAÑOL", "DEUTSCH", "FRANÇAIS", "POLSKI", "ქართული", "УКРАЇНСЬКА"]

# Tracks which destructive action the confirm dialog was opened for.
enum ConfirmAction { NONE, RESET_PROGRESS, DELETE_CUSTOM, UNLOCK_ALL }

@onready var title_label: Label = $ScreenHeaderHost/TitleLabel
@onready var lang_label: Label = $CenterContainer/OptionsPanel/VBoxContainer/LanguageContainer/LanguageLabel
@onready var prev_btn: Button = $CenterContainer/OptionsPanel/VBoxContainer/LanguageContainer/PrevLangButton
@onready var next_btn: Button = $CenterContainer/OptionsPanel/VBoxContainer/LanguageContainer/NextLangButton
@onready var bg_btn: Button = $CenterContainer/OptionsPanel/VBoxContainer/BackgroundButton
@onready var bgm_btn: Button = $CenterContainer/OptionsPanel/VBoxContainer/BgmButton
@onready var sfx_btn: Button = $CenterContainer/OptionsPanel/VBoxContainer/SfxButton
@onready var haptic_btn: Button = $CenterContainer/OptionsPanel/VBoxContainer/HapticButton
@onready var privacy_btn: Button = $CenterContainer/OptionsPanel/VBoxContainer/PrivacyPolicyButton
@onready var privacy_options_btn: Button = $CenterContainer/OptionsPanel/VBoxContainer/PrivacyOptionsButton
@onready var del_save_btn: Button = $CenterContainer/OptionsPanel/VBoxContainer/DeleteSaveButton
@onready var debug_buttons: VBoxContainer = $CenterContainer/OptionsPanel/VBoxContainer/DebugButtons
@onready var unlock_all_btn: Button = $CenterContainer/OptionsPanel/VBoxContainer/DebugButtons/UnlockAllButton
@onready var del_custom_btn: Button = $CenterContainer/OptionsPanel/VBoxContainer/DebugButtons/DeleteCustomButton
@onready var close_btn: Button = $CloseButtonHost/CloseOptionsButton
@onready var status_label: Label = $CenterContainer/OptionsPanel/VBoxContainer/StatusLabel
@onready var _options_center: Control = $CenterContainer
@onready var _screen_header_host: Control = $ScreenHeaderHost
@onready var _close_button_host: Control = $CloseButtonHost
@onready var _confirm_blocker: ColorRect = $ConfirmBlocker
@onready var _confirm_label: Label = $ConfirmBlocker/CenterContainer/Panel/VBoxContainer/PromptLabel
@onready var _confirm_yes_btn: Button = $ConfirmBlocker/CenterContainer/Panel/VBoxContainer/HBoxContainer/YesButton
@onready var _confirm_no_btn: Button = $ConfirmBlocker/CenterContainer/Panel/VBoxContainer/HBoxContainer/NoButton

# Which destructive action the confirm dialog is waiting on, or NONE if not shown.
var _pending_confirm: ConfirmAction = ConfirmAction.NONE
# When true, destructive buttons (reset progress, delete custom) are visible.
var _from_main_menu: bool = false
# Debug buttons (unlock all, delete custom) are only shown when opened from the main menu
# and GlobalGameManager.debug_tools_enabled is true.
var _show_debug_options: bool = false
# English scene authorship: title bottom at 412, options content starts at 500.
const _OPTIONS_BELOW_TITLE_GAP := 88.0

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
	if haptic_btn:
		haptic_btn.pressed.connect(_on_toggle_haptic)
	if privacy_btn:
		privacy_btn.pressed.connect(_on_privacy_policy_pressed)
	if privacy_options_btn:
		privacy_options_btn.pressed.connect(_on_privacy_options_pressed)
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
	_style_header()
	_update_lang_label()
	_update_background_label()
	_update_bgm_label()
	_update_sfx_label()
	_update_haptic_label()
	_fit_option_buttons()
	_style_close_button()
	if SaveManager and not SaveManager.language_changed.is_connected(_on_language_changed):
		SaveManager.language_changed.connect(_on_language_changed)
	if not get_viewport().size_changed.is_connected(_on_safe_area_viewport_resized):
		get_viewport().size_changed.connect(_on_safe_area_viewport_resized)

func _on_safe_area_viewport_resized() -> void:
	if visible:
		_layout_content_below_title()
		_style_close_button()

# Binds the i18n key and applies the screen-header visual style to the title label.
func _style_header() -> void:
	if not title_label:
		return
	HudLayout._bind_header_translation_key(title_label, "UI_OPTIONS")
	HudLayout.apply_screen_header_style(title_label)

# Opens the menu, refreshing all toggle labels and button visibility for the current context.
# Pass from_main_menu=true to show destructive/debug options not shown in-game.
func show_menu(from_main_menu: bool = false) -> void:
	_from_main_menu = from_main_menu
	_show_debug_options = from_main_menu and GlobalGameManager.debug_tools_enabled
	_configure_main_menu_buttons()
	_refresh_privacy_options_visibility()
	_update_lang_label()
	_update_background_label()
	_update_bgm_label()
	_update_sfx_label()
	_update_haptic_label()
	_fit_option_buttons()
	if status_label:
		status_label.text = ""
	_hide_confirm()
	visible = true
	if _screen_header_host:
		_screen_header_host.move_to_front()
	if _close_button_host:
		_close_button_host.move_to_front()
	call_deferred("_layout_content_below_title")

func hide_menu() -> void:
	_hide_confirm()
	visible = false
	back_requested.emit()

# Handles the Android system back button. If a confirm dialog is open, closes it first.
# Returns true if the back event was consumed (so the caller doesn't also navigate back).
func handle_system_back() -> bool:
	if not visible:
		return false
	if _confirm_blocker and _confirm_blocker.visible:
		_hide_confirm()
		return true
	hide_menu()
	return true

# Shows or hides buttons that are only appropriate when accessed from the main menu
# (reset progress) or in debug mode (unlock all, delete custom levels).
func _configure_main_menu_buttons() -> void:
	if del_save_btn:
		del_save_btn.visible = _from_main_menu
	var show_debug := _show_debug_options
	if debug_buttons:
		debug_buttons.visible = show_debug
	if unlock_all_btn:
		unlock_all_btn.visible = show_debug
		if show_debug:
			unlock_all_btn.text = "UI_UNLOCK_ALL_LEVELS"
			unlock_all_btn.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	if del_custom_btn:
		del_custom_btn.visible = show_debug
		if show_debug:
			del_custom_btn.text = "UI_DELETE_CUSTOM"
			del_custom_btn.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS

# Keeps the options button stack below the screen title with the same gap as the
# English layout, even when the localized header is taller.
func _layout_content_below_title() -> void:
	if title_label == null or _options_center == null:
		return
	title_label.offset_top = SafeInsets.padded_top(GameConstants.SCREEN_HEADER_TOP)
	var font := title_label.get_theme_font("font")
	var font_size := title_label.get_theme_font_size("font_size")
	var key := String(title_label.text)
	var display := tr(key) if key.begins_with("UI_") else key
	var outline := float(GameConstants.SCREEN_HEADER_OUTLINE)
	var text_h := GameConstants.SCREEN_HEADER_HEIGHT
	if font != null and not display.is_empty():
		var measured := font.get_string_size(
			display, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size
		)
		# Include outline so large default-font headers don't paint into the panel.
		text_h = maxf(
			GameConstants.SCREEN_HEADER_HEIGHT,
			measured.y + outline * 2.0 + 16.0
		)
	title_label.offset_bottom = title_label.offset_top + text_h
	_options_center.offset_top = title_label.offset_bottom + _OPTIONS_BELOW_TITLE_GAP
	if not _options_center.has_meta("_safe_b"):
		_options_center.set_meta("_safe_b", _options_center.offset_bottom)
		_options_center.set_meta("_safe_l", _options_center.offset_left)
		_options_center.set_meta("_safe_r", _options_center.offset_right)
	_options_center.offset_bottom = SafeInsets.padded_bottom_offset(
		float(_options_center.get_meta("_safe_b"))
	)
	_options_center.offset_left = float(_options_center.get_meta("_safe_l")) + SafeInsets.left()
	_options_center.offset_right = float(_options_center.get_meta("_safe_r")) - SafeInsets.right()

# The "Privacy Options" button is only visible when UMP has a form ready to display
# (i.e. the user is in a region that requires consent management).
func _refresh_privacy_options_visibility() -> void:
	if not privacy_options_btn:
		return
	var show_privacy_options := false
	if AdsManager:
		show_privacy_options = (
			AdsManager.get_privacy_options_state() == AdsManager.PRIVACY_OPTIONS_STATE_READY
		)
	privacy_options_btn.visible = show_privacy_options

# Refreshes the language display label to show the current locale's native name.
# The lang label always uses the locale's own script (never auto-translated).
func _update_lang_label() -> void:
	if not lang_label:
		return
	var current_locale = TranslationServer.get_locale().substr(0, 2)
	var idx = LANGUAGES.find(current_locale)
	if idx == -1:
		idx = 0
	# Always use the fixed display name — never a translated/baked string.
	var name_text: String = LANG_NAMES[idx]
	lang_label.custom_minimum_size = Vector2(380, GameConstants.UI_BTN_PRIMARY_SIZE.y)
	lang_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lang_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lang_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	lang_label.clip_text = false
	HudLayout._clear_pixel_raster(lang_label)
	# Drop any scene-baked Press Start override so a poisoned atlas can't stick.
	if lang_label.has_theme_font_override("font"):
		lang_label.remove_theme_font_override("font")
	var font_size := HudLayout.scaled_font_size(GameConstants.UI_BODY_FONT_SIZE_LARGE)
	# Latin names (ENGLISH, …) stay Press Start even in ka/uk; native names use Noto.
	if HudFonts.should_use_press_start_font(name_text):
		HudLayout.apply_raster_pixel_label(lang_label, name_text, font_size, Color.WHITE)
	else:
		HudLayout.clear_label_settings(lang_label)
		lang_label.set_meta("_use_default_font", true)
		lang_label.set_meta("_force_pixel_font", false)
		lang_label.text = name_text
		lang_label.add_theme_font_override("font", HudFonts.default_font())
		lang_label.add_theme_font_size_override("font_size", font_size)
		HudLayout.apply_safe_outline(lang_label, GameConstants.MENU_TEXT_OUTLINE)

# Prev/next language arrows always use Press Start (including ka/uk locales).
func _style_lang_nav_button(button: Button, symbol: String) -> void:
	if button == null:
		return
	button.custom_minimum_size = Vector2(100, 100)
	button.flat = false
	button.focus_mode = Control.FOCUS_NONE
	_apply_button_tile_styles(button)
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var font_size := HudLayout.scaled_font_size(GameConstants.UI_BTN_PRIMARY_FONT)
	HudLayout.apply_raster_pixel_button(button, symbol, font_size)
	HudLayout.fit_text_button(
		button, GameConstants.UI_BTN_PRIMARY_FONT, GameConstants.UI_BTN_PRIMARY_FONT_MIN
	)

# Re-measures and resizes all option buttons to fit their translated text,
# and re-styles the language prev/next arrows and confirm dialog texts.
# Must be called after any locale change because font metrics differ per locale.
func _fit_option_buttons() -> void:
	if title_label:
		HudLayout._bind_header_translation_key(title_label, "UI_OPTIONS")
		HudLayout.apply_screen_header_style(title_label)
	_bind_option_button_keys()
	for btn in [del_save_btn, bg_btn, bgm_btn, sfx_btn, haptic_btn, privacy_btn, privacy_options_btn, del_custom_btn, unlock_all_btn]:
		_apply_option_button(btn)
	_style_close_button()
	if prev_btn:
		_style_lang_nav_button(prev_btn, "<")
	if next_btn:
		_style_lang_nav_button(next_btn, ">")
	_update_lang_label()
	_layout_content_below_title()
	call_deferred("_layout_content_below_title")
	_refresh_confirm_texts()

# Re-binds i18n keys before sizing so locale changes re-translate correctly.
func _bind_option_button_keys() -> void:
	if privacy_btn:
		privacy_btn.text = "UI_PRIVACY_POLICY"
		privacy_btn.set_meta("_tr_key", "UI_PRIVACY_POLICY")
		privacy_btn.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	if privacy_options_btn:
		privacy_options_btn.text = "UI_PRIVACY_OPTIONS"
		privacy_options_btn.set_meta("_tr_key", "UI_PRIVACY_OPTIONS")
		privacy_options_btn.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	if del_save_btn and del_save_btn.visible:
		del_save_btn.text = "UI_RESET_PROGRESS"
		del_save_btn.set_meta("_tr_key", "UI_RESET_PROGRESS")
		del_save_btn.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS

# Applies the gray-dark tile style to a single option button and sizes it so its
# translated text fits on one line with standard padding. Toggle rows skip text override since
# their label lives in a ToggleCaptionHost RichTextLabel child.
# Latin locales (not ka/uk): Press Start via PixelSafeCaption — Button theme font scrambles
# under GL Compatibility. ka/uk: Noto on the button for native-script labels.
func _apply_option_button(button: Button) -> void:
	if not button or not button.visible:
		return
	button.focus_mode = Control.FOCUS_NONE
	button.flat = false
	_apply_button_tile_styles(button)
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.clip_text = false
	HudLayout._clear_pixel_raster(button)
	var font_size := HudLayout.scaled_font_size(GameConstants.UI_BTN_PRIMARY_FONT)
	var display := _option_button_display_text(button)
	# Press Start for Latin/digits/symbols even in ka/uk; Noto only for native letters.
	var use_pixel := HudFonts.should_use_press_start_font(display)
	button.set_meta("_use_default_font", not use_pixel)
	button.set_meta("_force_pixel_font", use_pixel and _is_plain_text_option_button(button))
	var font: Font = HudLayout.pixel_font() if use_pixel else HudFonts.default_font()
	if font == null:
		font = HudFonts.default_font()
	var pad_x := 56.0 + float(GameConstants.MENU_TEXT_OUTLINE) + 16.0
	var pad_y := 48.0 + float(GameConstants.MENU_TEXT_OUTLINE) + 16.0
	var min_h := maxf(100.0, float(font_size) + pad_y)
	# Toggle rows keep empty button text; caption RichTextLabel draws the label.
	if button.get_node_or_null("ToggleCaptionHost") != null:
		button.text = ""
		button.set_meta("_force_pixel_font", false)
		HudLayout.apply_locale_font_to_control(button)
		var caption_display := _option_button_display_text(button)
		if not caption_display.is_empty():
			var caption_size := font.get_string_size(
				caption_display, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size
			)
			button.custom_minimum_size = Vector2(maxf(220.0, caption_size.x + pad_x), min_h)
		else:
			button.custom_minimum_size = Vector2(220.0, min_h)
		HudLayout.apply_safe_outline(button, GameConstants.MENU_TEXT_OUTLINE)
		return
	var measure_text := display if not display.is_empty() else "M"
	var measured := font.get_string_size(
		measure_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size
	)
	button.custom_minimum_size = Vector2(maxf(220.0, measured.x + pad_x), min_h)
	if use_pixel:
		# Privacy / reset / debug: Press Start caption (never Button theme font).
		var key := String(button.get_meta("_tr_key", button.text)).strip_edges()
		if key.is_empty() and not display.is_empty():
			key = display
		if not key.is_empty():
			button.set_meta("_tr_key", key)
		if display.is_empty() and not key.is_empty():
			display = String(TranslationServer.translate(key))
		HudLayout.apply_raster_pixel_button(button, display, font_size, 0, true)
		return
	if not display.is_empty():
		var key := String(button.get_meta("_tr_key", "")).strip_edges()
		if key.is_empty():
			key = button.text.strip_edges()
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
		button.text = key if not key.is_empty() else display
	button.set_meta("_force_pixel_font", false)
	HudLayout.apply_locale_font_to_control(button)
	button.add_theme_font_size_override("font_size", HudLayout.body_font_size(font_size))
	HudLayout.apply_safe_outline(button, GameConstants.MENU_TEXT_OUTLINE)

# Privacy / reset / debug rows draw label text on the Button itself (not a toggle caption).
func _is_plain_text_option_button(button: Button) -> bool:
	return (
		button == privacy_btn
		or button == privacy_options_btn
		or button == del_save_btn
		or button == del_custom_btn
		or button == unlock_all_btn
	)

# Returns the display text for an option button, preferring the ToggleCaptionHost
# RichTextLabel if present (so toggle buttons don't measure stale .text).
func _option_button_display_text(button: Button) -> String:
	if button == null:
		return ""
	var host := button.get_node_or_null("ToggleCaptionHost") as Control
	if host:
		var caption := host.get_node_or_null("ToggleCaption") as RichTextLabel
		if caption and not caption.get_parsed_text().is_empty():
			return caption.get_parsed_text().strip_edges()
	var key := String(button.get_meta("_tr_key", "")).strip_edges()
	var raw := button.text.strip_edges()
	if raw.is_empty():
		raw = key
	if raw.is_empty():
		return ""
	if _is_message_key(raw) or button.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED:
		return String(TranslationServer.translate(raw))
	return raw

func _is_message_key(text: String) -> bool:
	return HudLayout._is_i18n_key(text) or (
		not text.is_empty() and text == text.to_upper() and text[0] >= "A" and text[0] <= "Z"
	)

# Applies the 9-slice gray-dark tile texture to all visual states of an option button.
# Local copy of HudLayout.apply_top_bar_tile_styles so options_menu can be standalone.
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

# Delegates close button styling to HudLayout so it matches all other close buttons.
func _style_close_button() -> void:
	if close_btn == null:
		return
	HudLayout.style_top_bar_close_button(close_btn)

# Gold accent color used to highlight the current value (ON/OFF/DYNAMIC) in toggle captions.
const _TOGGLE_ACCENT := Color(1.0, 0.84, 0.0, 1.0)

# Renders a toggle button's label as BBCode in a RichTextLabel child,
# coloring only the value part (after the last colon) in the accent gold.
# This avoids naive "ON" substring replacement that would match "ON" inside "VIBRATION".
func _set_toggle_button_caption(button: Button, full_text: String) -> void:
	if not button:
		return
	button.text = ""
	HudLayout._clear_pixel_raster(button)
	var legacy := button.get_node_or_null("ToggleCaption")
	if legacy:
		legacy.queue_free()
	var host := button.get_node_or_null("ToggleCaptionHost") as CenterContainer
	var font_size := HudLayout.scaled_font_size(GameConstants.UI_BTN_PRIMARY_FONT)
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
		host.add_child(caption)
	button.move_child(host, -1)
	var use_pixel := HudFonts.should_use_press_start_font(full_text)
	caption.set_meta("_use_default_font", not use_pixel)
	button.set_meta("_use_default_font", not use_pixel)
	if use_pixel:
		# Latin-only: Press Start, no theme outline (outline scrambles glyphs).
		HudLayout.apply_live_pixel_richtext(caption, font_size)
	else:
		caption.add_theme_font_override("normal_font", HudFonts.default_font())
		caption.add_theme_font_override("bold_font", HudFonts.default_font())
		caption.add_theme_font_override("italics_font", HudFonts.default_font())
		caption.add_theme_font_override("bold_italics_font", HudFonts.default_font())
		caption.add_theme_font_override("mono_font", HudFonts.default_font())
		caption.add_theme_color_override("font_outline_color", Color.BLACK)
		HudLayout.apply_safe_outline(caption, GameConstants.MENU_TEXT_OUTLINE)
		caption.add_theme_font_size_override("normal_font_size", font_size)
	var accent := _TOGGLE_ACCENT.to_html(false)
	# Color only the value after the last colon (ON/OFF, AN/AUS, DYNAMIC…).
	# Substring replace of "ON" would paint the "ON" inside "VIBRATION".
	var left := full_text
	var right := ""
	var colon := full_text.rfind(":")
	if colon >= 0 and colon < full_text.length() - 1:
		left = full_text.substr(0, colon + 1)
		right = full_text.substr(colon + 1)
	var space_end := 0
	while space_end < right.length() and right[space_end] == " ":
		space_end += 1
	var spaces := right.substr(0, space_end)
	var value := right.substr(space_end)
	if not use_pixel:
		left = HudFonts.wrap_press_start_runs_bbcode(left, font_size)
		value = HudFonts.wrap_press_start_runs_bbcode(value, font_size)
	var colored: String
	if right.is_empty():
		colored = (
			full_text if use_pixel else HudFonts.wrap_press_start_runs_bbcode(full_text, font_size)
		)
	else:
		colored = "%s%s[color=#%s]%s[/color]" % [left, spaces, accent, value]
	caption.text = "[center]%s[/center]" % colored
	_apply_option_button(button)

# Refreshes each toggle button to show the current setting value in gold accent text.
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

func _update_haptic_label() -> void:
	if not haptic_btn:
		return
	_set_toggle_button_caption(
		haptic_btn, tr("UI_HAPTIC_ON" if SaveManager.haptic_enabled else "UI_HAPTIC_OFF")
	)

func _on_language_changed() -> void:
	if not visible:
		return
	_update_lang_label()
	_update_background_label()
	_update_bgm_label()
	_update_sfx_label()
	_update_haptic_label()
	_fit_option_buttons()

# Cycles to the previous language in the LANGUAGES array (wraps around).
# Refreshes all toggle labels and button sizes because font metrics change per locale.
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
	_update_haptic_label()
	_fit_option_buttons()

# Cycles to the next language in the LANGUAGES array (wraps around).
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
	_update_haptic_label()
	_fit_option_buttons()

# Toggle handlers: flip the saved setting and refresh the button caption immediately.
func _on_toggle_background() -> void:
	SaveManager.set_background_static(not SaveManager.background_static)
	_update_background_label()

func _on_toggle_bgm() -> void:
	SaveManager.set_bgm_enabled(not SaveManager.bgm_enabled)
	_update_bgm_label()

func _on_toggle_sfx() -> void:
	SaveManager.set_sfx_enabled(not SaveManager.sfx_enabled)
	_update_sfx_label()

func _on_toggle_haptic() -> void:
	SaveManager.set_haptic_enabled(not SaveManager.haptic_enabled)
	_update_haptic_label()

# Opens the privacy policy URL via AdsManager (which knows the canonical URL),
# or falls back to OS.shell_open if AdsManager is unavailable (editor/desktop).
func _on_privacy_policy_pressed() -> void:
	if AdsManager:
		AdsManager.open_privacy_policy()
	else:
		OS.shell_open("https://geeks0n-byte.github.io/project-taku/privacy-policy.html")

# Opens the UMP privacy options form if available. Falls back to the privacy policy URL
# if the form isn't ready (e.g. outside EEA or ads not yet initialised).
func _on_privacy_options_pressed() -> void:
	if AdsManager and AdsManager.get_privacy_options_state() == AdsManager.PRIVACY_OPTIONS_STATE_READY:
		AdsManager.show_privacy_options_form()
		return
	if AdsManager:
		AdsManager.open_privacy_policy()
	else:
		OS.shell_open("https://geeks0n-byte.github.io/project-taku/privacy-policy.html")

# Initializes the confirmation dialog (styling, signal connections, initial text).
# Called once from _ready; safe to call again after a locale change.
func _setup_confirm_panel() -> void:
	if _confirm_blocker:
		_confirm_blocker.visible = false
		_confirm_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
		# Match other popups: no dim overlay — chrome is hidden instead.
		_confirm_blocker.color = Color(0, 0, 0, 0)
	var center := _confirm_blocker.get_node_or_null("CenterContainer") as Control if _confirm_blocker else null
	if center:
		HudLayout.raise_centered_dialog_host(center)
	var panel := _confirm_blocker.get_node_or_null("CenterContainer/Panel") as Panel if _confirm_blocker else null
	if panel:
		panel.add_theme_stylebox_override("panel", HudLayout.make_dialog_panel_style())
	if _confirm_yes_btn and not _confirm_yes_btn.pressed.is_connected(_on_confirm_yes):
		_confirm_yes_btn.pressed.connect(_on_confirm_yes)
	if _confirm_no_btn and not _confirm_no_btn.pressed.is_connected(_hide_confirm):
		_confirm_no_btn.pressed.connect(_hide_confirm)
	if _confirm_yes_btn:
		_confirm_yes_btn.set_meta("_tr_key", "UI_YES")
	if _confirm_no_btn:
		_confirm_no_btn.set_meta("_tr_key", "UI_NO")
	_copy_button_styles(_confirm_yes_btn)
	_copy_button_styles(_confirm_no_btn)
	_refresh_confirm_texts()

func _set_options_chrome_visible(should_show: bool) -> void:
	if _options_center:
		_options_center.visible = should_show
	if _screen_header_host:
		_screen_header_host.visible = should_show
	if _close_button_host:
		_close_button_host.visible = should_show

# Copies the tile StyleBox from an existing styled button so confirm dialog buttons
# look consistent without needing their own StyleBoxTexture resources in the scene.
func _copy_button_styles(target: Button) -> void:
	var source := close_btn if close_btn else del_save_btn
	if not source or not target:
		return
	for style_name in ["normal", "pressed", "hover", "disabled"]:
		var style := source.get_theme_stylebox(style_name)
		if style:
			target.add_theme_stylebox_override(style_name, style)
	target.add_theme_color_override("font_outline_color", Color.BLACK)
	HudLayout.apply_safe_outline(target, GameConstants.MENU_TEXT_OUTLINE)

# Re-translates the confirm dialog button labels and prompt text.
# Must be called after a locale change so the dialog doesn't show stale text.
func _refresh_confirm_texts() -> void:
	if _confirm_yes_btn:
		var yes_text := tr("UI_YES")
		_confirm_yes_btn.text = yes_text
		HudLayout.apply_dialog_button(_confirm_yes_btn, yes_text)
	if _confirm_no_btn:
		var no_text := tr("UI_NO")
		_confirm_no_btn.text = no_text
		HudLayout.apply_dialog_button(_confirm_no_btn, no_text)
	if _confirm_label:
		match _pending_confirm:
			ConfirmAction.RESET_PROGRESS:
				_confirm_label.text = tr("CONFIRM_RESET_PROGRESS")
			ConfirmAction.DELETE_CUSTOM:
				_confirm_label.text = tr("CONFIRM_DELETE_CUSTOM")
			ConfirmAction.UNLOCK_ALL:
				_confirm_label.text = tr("CONFIRM_UNLOCK_ALL")
			_:
				if _confirm_label.text.is_empty():
					_confirm_label.text = tr("CONFIRM_RESET_PROGRESS")
		var prompt_color := (
			Color(0.45, 1.0, 0.45)
			if _pending_confirm == ConfirmAction.UNLOCK_ALL
			else Color(1.0, 0.45, 0.45)
		)
		_confirm_label.add_theme_color_override("font_color", prompt_color)
		HudLayout.apply_popup_label(_confirm_label, GameConstants.UI_BODY_FONT_SIZE_LARGE)
	if _confirm_blocker and _confirm_blocker.visible:
		var panel := _confirm_blocker.get_node_or_null("CenterContainer/Panel") as Panel
		if panel:
			HudLayout.fit_dialog_panel(panel, HudLayout.UI_DEFAULT_DIALOG_WIDTH)

# Shows the confirmation overlay for a destructive action with the appropriate message.
func _show_confirm(action: ConfirmAction, message: String) -> void:
	_pending_confirm = action
	if _confirm_label:
		_confirm_label.text = message
	_refresh_confirm_texts()
	var panel := _confirm_blocker.get_node_or_null("CenterContainer/Panel") as Panel if _confirm_blocker else null
	if panel:
		HudLayout.fit_dialog_panel(panel, HudLayout.UI_DEFAULT_DIALOG_WIDTH)
	_set_options_chrome_visible(false)
	if _confirm_blocker:
		_confirm_blocker.color = Color(0, 0, 0, 0)
		_confirm_blocker.visible = true

func _hide_confirm() -> void:
	_pending_confirm = ConfirmAction.NONE
	if _confirm_blocker:
		_confirm_blocker.visible = false
	_set_options_chrome_visible(true)

# Dispatches the confirmed destructive action and clears the pending state.
func _on_confirm_yes() -> void:
	var action := _pending_confirm
	_hide_confirm()
	match action:
		ConfirmAction.RESET_PROGRESS:
			_do_delete_save()
		ConfirmAction.DELETE_CUSTOM:
			_do_delete_custom()
		ConfirmAction.UNLOCK_ALL:
			_do_unlock_all()

func _on_delete_save_pressed() -> void:
	_show_confirm(ConfirmAction.RESET_PROGRESS, tr("CONFIRM_RESET_PROGRESS"))

func _on_delete_custom_pressed() -> void:
	_show_confirm(ConfirmAction.DELETE_CUSTOM, tr("CONFIRM_DELETE_CUSTOM"))

# Debug tool: confirm, then unlock every campaign level and show a green status.
func _on_unlock_all_pressed() -> void:
	_show_confirm(ConfirmAction.UNLOCK_ALL, tr("CONFIRM_UNLOCK_ALL"))

func _do_unlock_all() -> void:
	SaveManager.unlock_all_levels()
	_show_status_message(tr("UNLOCK_ALL_DONE"), Color(0.45, 1.0, 0.45))

# Wipes the save file and emits save_deleted so callers (main menu) can react.
func _do_delete_save() -> void:
	SaveManager.delete_save_file()
	if status_label:
		status_label.text = ""
	save_deleted.emit()

# Deletes all .tres and .remap files from the user's custom levels directory.
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
	_show_status_message(tr("CUSTOM_DELETED"), Color(1.0, 0.35, 0.35))

func _show_status_message(msg: String, color: Color) -> void:
	if not status_label:
		return
	status_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	status_label.modulate = color
	# Routes Latin/digits to Press Start even in ka/uk; native letters use Noto.
	HudLayout.apply_raster_pixel_label(
		status_label, msg, GameConstants.UI_BODY_FONT_SIZE, color
	)
