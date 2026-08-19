extends ColorRect

signal accepted
signal read_policy

const _TILE_TEX := preload("res://resources/buttons/button_tile_gray_dark.svg")

@onready var _title: Label       = $Outer/Content/ConsentTitle
@onready var _body: Label        = $Outer/Content/ConsentBody
@onready var _read_btn: Button   = $Outer/Content/ReadPolicyButton
@onready var _accept_btn: Button = $Outer/Content/AcceptButton

func _ready() -> void:
	_read_btn.pressed.connect(_on_read_policy)
	_accept_btn.pressed.connect(_on_accepted)
	HudLayout.apply_popup_label(_title, 80)
	HudLayout.apply_safe_outline(_title, GameConstants.MENU_TEXT_OUTLINE)
	HudLayout.apply_popup_label(_body, 44)
	HudLayout.apply_safe_outline(_body, GameConstants.MENU_TEXT_OUTLINE)
	HudLayout.apply_tile_button(_read_btn, _TILE_TEX)
	HudLayout.apply_tile_button(_accept_btn, _TILE_TEX)

func _on_read_policy() -> void:
	OS.shell_open(GameConstants.PRIVACY_POLICY_URL)
	read_policy.emit()

func _on_accepted() -> void:
	hide()
	accepted.emit()
