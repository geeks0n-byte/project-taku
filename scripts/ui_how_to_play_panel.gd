class_name UiHowToPlayPanel
extends RefCounted
## How-to-play overlay pages for the gameplay HUD.


var _container: Control
var _panel: Control
var _header: Label
var _nav: HBoxContainer
var _prev: Button
var _next: Button
var _rules: RichTextLabel
var _page: int = 0
var _queue_layout: Callable


func bind(
	container: Control,
	panel: Control,
	header: Label,
	nav: HBoxContainer,
	prev_button: Button,
	next_button: Button,
	rules_label: RichTextLabel
) -> void:
	_container = container
	_panel = panel
	_header = header
	_nav = nav
	_prev = prev_button
	_next = next_button
	_rules = rules_label


func setup(queue_layout: Callable = Callable()) -> void:
	_queue_layout = queue_layout
	layout_chrome()
	setup_rules_font()
	refresh_text()


func layout_chrome() -> void:
	for btn in [_prev, _next]:
		HudLayout.apply_nav_button(btn)


func setup_rules_font() -> void:
	if not _rules:
		return
	_rules.set_meta("_use_default_font", true)
	HudLayout.apply_locale_font_to_control(_rules)


func on_locale_changed() -> void:
	if _container:
		HudLayout.clear_how_to_play_nav_lock(_container)
	refresh_text()


func page() -> int:
	return _page


func show_panel() -> void:
	_page = 0
	if _container:
		HudLayout.clear_how_to_play_nav_lock(_container)
	refresh_text()
	if _container:
		_container.visible = true


func hide_panel() -> void:
	if _container:
		_container.visible = false


func is_visible() -> bool:
	return _container != null and _container.visible


func on_prev_pressed() -> void:
	_page = maxi(_page - 1, 0)
	refresh_text()


func on_next_pressed() -> void:
	_page = mini(_page + 1, HowToPlayContent.PAGE_COUNT - 1)
	refresh_text()


func refresh_text() -> void:
	if _header:
		HudLayout._bind_header_translation_key(
			_header, HowToPlayContent.get_page_title_key(_page)
		)
		HudLayout.apply_screen_header_style(_header)
	if _rules:
		_rules.text = HowToPlayContent.get_page_text(_page)
		setup_rules_font()
	if _prev:
		_prev.visible = _page > 0
		_prev.disabled = false
		HudLayout.apply_nav_button(_prev)
		HudLayout.refresh_button_icon_modulate(_prev)
	if _next:
		_next.visible = _page < HowToPlayContent.PAGE_COUNT - 1
		_next.disabled = false
		HudLayout.apply_nav_button(_next)
		HudLayout.refresh_button_icon_modulate(_next)
	if _queue_layout.is_valid():
		_queue_layout.call_deferred()
	apply_a11y_labels()


func apply_a11y_labels() -> void:
	A11yLabels.bind_button(_prev, "UI_PREVIOUS")
	A11yLabels.bind_button(_next, "UI_NEXT")
	if _header:
		A11yLabels.bind_label(_header, HowToPlayContent.get_page_title_key(_page))
	if _rules:
		A11yLabels.bind_rich_text(_rules)


func layout_stack() -> void:
	if _container == null:
		return
	HudLayout.layout_how_to_play_stack(
		_container,
		_panel,
		_rules,
		_nav,
		_page == 0,
		true
	)
