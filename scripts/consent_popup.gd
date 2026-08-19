extends ColorRect

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

func _ready() -> void:
	_read_btn.pressed.connect(_on_read_policy)
	_accept_btn.pressed.connect(_on_accepted)
	# Visual layout is defined in consent_popup.tscn.
	# These calls apply dynamic font sizing that can't be set in the scene editor.
	HudLayout.apply_popup_label(_title, 80)
	HudLayout.apply_safe_outline(_title, GameConstants.MENU_TEXT_OUTLINE)
	HudLayout.apply_popup_label(_body, 44)
	HudLayout.apply_safe_outline(_body, GameConstants.MENU_TEXT_OUTLINE)
	HudLayout.apply_tile_button(_read_btn, _TILE_TEX)
	HudLayout.apply_tile_button(_accept_btn, _TILE_TEX)

# Opens the privacy policy URL in the device's default browser.
func _on_read_policy() -> void:
	OS.shell_open(GameConstants.PRIVACY_POLICY_URL)
	read_policy.emit()

# Hides the popup and notifies main_menu.gd to save acceptance and show the menu.
func _on_accepted() -> void:
	hide()
	accepted.emit()
