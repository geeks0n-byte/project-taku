extends ColorRect
## First-launch privacy consent overlay; ACCEPT unblocks the main menu.

# Emitted when the player taps ACCEPT. main_menu.gd listens to this
# to save privacy_accepted and reveal the main menu UI.
signal accepted

# Emitted when the player taps the privacy policy button (informational only).
signal read_policy

# The tile texture used for the consent buttons (same gray-dark style as other overlays).
const _TILE_TEX := preload("res://resources/buttons/button_tile_gray_dark.svg")

@onready var _title: Label     = $Outer/Content/ConsentTitle
@onready var _body: Label      = $Outer/Content/ConsentBody
@onready var _read_btn: Button = $Outer/Content/ReadPolicyButton
@onready var _accept_btn: Button = $Outer/Content/AcceptButton

## Wires buttons, locale refresh, and viewport resize so the panel stays fitted.
func _ready() -> void:
	_read_btn.pressed.connect(_on_read_policy)
	_accept_btn.pressed.connect(_on_accepted)
	refresh_locale()
	if SaveManager and not SaveManager.language_changed.is_connected(refresh_locale):
		SaveManager.language_changed.connect(refresh_locale)
	if not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)

## Refits the content column when the overlay is visible.
func _on_viewport_resized() -> void:
	if visible:
		call_deferred("_fit_layout")

# Re-applies translated copy + fonts for the active locale.
# Must run whenever the popup is shown after a language change (e.g. reset profile).
func refresh_locale() -> void:
	_apply_locale_texts()
	call_deferred("_fit_layout")

## Writes translated title/body/buttons and applies popup fonts.
func _apply_locale_texts() -> void:
	if _title:
		_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_title.set_meta("_tr_key", "UI_CONSENT_TITLE")
		_title.text = tr("UI_CONSENT_TITLE")
		HudLayout.apply_popup_label(_title, 80)
		HudLayout.apply_safe_outline(_title, GameConstants.MENU_TEXT_OUTLINE)
	if _body:
		_body.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_body.set_meta("_tr_key", "UI_CONSENT_BODY")
		_body.text = tr("UI_CONSENT_BODY")
		HudLayout.apply_popup_label(_body, 44)
		HudLayout.apply_safe_outline(_body, GameConstants.MENU_TEXT_OUTLINE)
	if _read_btn:
		_read_btn.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_read_btn.text = tr("UI_CONSENT_READ_POLICY")
		HudLayout.apply_tile_button(_read_btn, _TILE_TEX)
	if _accept_btn:
		_accept_btn.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_accept_btn.text = tr("UI_CONSENT_ACCEPT")
		HudLayout.apply_tile_button(_accept_btn, _TILE_TEX)

## Sizes the content column to the dialog width used by other popups.
func _fit_layout() -> void:
	var content := get_node_or_null("Outer/Content") as Control
	if content == null:
		return
	HudDialogs.fit_content_column(content, 760.0, HudDialogs.DIALOG_EXTRA_PAD_V, 200.0, 1600.0, false)

# Opens the privacy policy URL in the device's default browser.
func _on_read_policy() -> void:
	OS.shell_open(GameConstants.PRIVACY_POLICY_URL)
	read_policy.emit()

# Hides the popup and notifies main_menu.gd to save acceptance and show the menu.
func _on_accepted() -> void:
	hide()
	accepted.emit()
