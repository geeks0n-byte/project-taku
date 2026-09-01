class_name A11yLabels
extends RefCounted
## Binds translated accessibility names onto primary UI controls.


static func bind_button(btn: Button, translation_key: String) -> void:
	if btn == null:
		return
	var label := String(TranslationServer.translate(translation_key))
	if label.is_empty():
		label = translation_key
	btn.accessibility_name = label


static func bind_buttons(pairs: Array) -> void:
	for entry in pairs:
		if typeof(entry) != TYPE_ARRAY or entry.size() < 2:
			continue
		bind_button(entry[0] as Button, str(entry[1]))
