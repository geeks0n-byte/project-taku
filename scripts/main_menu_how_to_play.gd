class_name MainMenuHowToPlay
extends RefCounted
## Main-menu how-to-play overlay. Pages and layout live in UiHowToPlayPanel;
## this wrapper only hides menu chrome and wires the close control.

var _panel := UiHowToPlayPanel.new()
var _host: Control
var _close: Button
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
	_host = htp_host
	_close = htp_close
	_set_chrome_visible = set_chrome_visible
	_panel.bind(
		htp_host,
		htp_panel,
		htp_header,
		htp_nav,
		htp_prev,
		htp_next,
		htp_rules,
		htp_close,
		true
	)


func setup_overlay() -> void:
	if _host:
		_host.visible = false
		_host.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.setup()


func bind_signals() -> void:
	_panel.bind_nav_signals()
	if _close and not _close.pressed.is_connected(close):
		_close.pressed.connect(close)


func is_blocking() -> bool:
	return _panel.is_visible()


func handle_back() -> bool:
	if not is_blocking():
		return false
	close()
	return true


func open() -> void:
	MainMenuChrome.set_visible(_set_chrome_visible, false)
	_panel.show_panel()
	if _host:
		_host.move_to_front()


func close() -> void:
	_panel.hide_panel()
	MainMenuChrome.set_visible(_set_chrome_visible, true)


func refresh_text() -> void:
	_panel.refresh_text()


func apply_a11y_labels() -> void:
	_panel.apply_a11y_labels()
