class_name MainMenuHowToPlay
extends RefCounted

var _htp_host: Control
var _htp_header: Label
var _htp_panel: Control
var _htp_nav: HBoxContainer
var _htp_rules: RichTextLabel
var _htp_prev: Button
var _htp_close: Button
var _htp_next: Button
var _htp_page: int = 0
var _set_chrome_visible: Callable


func setup(
	htp_host: Control,
	htp_header: Label,
	htp_panel: Control,
	htp_nav: HBoxContainer,
	htp_rules: RichTextLabel,
	htp_prev: Button,
	htp_close: Button,
	htp_next: Button,
	set_chrome_visible: Callable
) -> void:
	_htp_host = htp_host
	_htp_header = htp_header
	_htp_panel = htp_panel
	_htp_nav = htp_nav
	_htp_rules = htp_rules
	_htp_prev = htp_prev
	_htp_close = htp_close
	_htp_next = htp_next
	_set_chrome_visible = set_chrome_visible


func setup_overlay() -> void:
	if _htp_host:
		_htp_host.visible = false
		_htp_host.mouse_filter = Control.MOUSE_FILTER_STOP
	if _htp_rules:
		_htp_rules.set_meta("_use_default_font", true)
		_htp_rules.add_theme_color_override("default_color", Color.WHITE)
		HudLayout.apply_safe_outline(_htp_rules, GameConstants.MENU_TEXT_OUTLINE)
	for btn in [_htp_prev, _htp_next]:
		HudLayout.apply_nav_button(btn)
	if _htp_close:
		HudLayout.style_top_bar_close_button(_htp_close)
	refresh_text()


func bind_signals() -> void:
	if _htp_prev and not _htp_prev.pressed.is_connected(_on_prev):
		_htp_prev.pressed.connect(_on_prev)
	if _htp_close and not _htp_close.pressed.is_connected(close):
		_htp_close.pressed.connect(close)
	if _htp_next and not _htp_next.pressed.is_connected(_on_next):
		_htp_next.pressed.connect(_on_next)


func is_blocking() -> bool:
	return _htp_host != null and _htp_host.visible


func handle_back() -> bool:
	if not is_blocking():
		return false
	close()
	return true


func open() -> void:
	MainMenuChrome.set_visible(_set_chrome_visible, false)
	_htp_page = 0
	HudLayout.clear_how_to_play_nav_lock(_htp_host)
	refresh_text()
	if _htp_host:
		_htp_host.visible = true
		_htp_host.move_to_front()


func close() -> void:
	if _htp_host:
		_htp_host.visible = false
	MainMenuChrome.set_visible(_set_chrome_visible, true)


func refresh_text() -> void:
	if _htp_header:
		HudLayout._bind_header_translation_key(
			_htp_header, HowToPlayContent.get_page_title_key(_htp_page)
		)
		HudLayout.apply_screen_header_style(_htp_header)
	if _htp_rules:
		_htp_rules.text = HowToPlayContent.get_page_text(_htp_page)
		HudLayout.apply_locale_font_to_control(_htp_rules)
	if _htp_prev:
		_htp_prev.visible = _htp_page > 0
		HudLayout.apply_nav_button(_htp_prev)
	if _htp_next:
		_htp_next.visible = _htp_page < HowToPlayContent.PAGE_COUNT - 1
		HudLayout.apply_nav_button(_htp_next)
	if _htp_close:
		HudLayout.style_top_bar_close_button(_htp_close)
	apply_a11y_labels()
	_layout_stack.call_deferred()


func apply_a11y_labels() -> void:
	A11yLabels.bind_button(_htp_close, "UI_CLOSE")
	A11yLabels.bind_button(_htp_prev, "UI_PREVIOUS")
	A11yLabels.bind_button(_htp_next, "UI_NEXT")
	if _htp_header:
		A11yLabels.bind_label(_htp_header, HowToPlayContent.get_page_title_key(_htp_page))
	if _htp_rules:
		A11yLabels.bind_rich_text(_htp_rules)


func _layout_stack() -> void:
	HudLayout.layout_how_to_play_stack(
		_htp_host, _htp_panel, _htp_rules, _htp_nav, _htp_page == 0, true
	)


func _on_prev() -> void:
	_htp_page = maxi(_htp_page - 1, 0)
	refresh_text()


func _on_next() -> void:
	_htp_page = mini(_htp_page + 1, HowToPlayContent.PAGE_COUNT - 1)
	refresh_text()
