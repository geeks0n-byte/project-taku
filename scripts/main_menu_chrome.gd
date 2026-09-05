class_name MainMenuChrome
extends RefCounted
## Single Callable contract for main-menu overlay chrome: set_menu_chrome_visible(visible, preserve_title_on_hide).


static func set_visible(
	callable: Callable,
	should_show: bool,
	preserve_title_on_hide: bool = false
) -> void:
	if not callable.is_valid():
		return
	if preserve_title_on_hide and not should_show:
		callable.call(should_show, true)
	else:
		callable.call(should_show)
