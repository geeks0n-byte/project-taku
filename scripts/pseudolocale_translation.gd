class_name PseudolocaleTranslation
extends Translation
## Wraps English strings with accent expansion for layout QA.


func _get_message(message: StringName, context: StringName = &"") -> StringName:
	var saved := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var base := String(TranslationServer.translate(message, context))
	if base.is_empty() or base == String(message):
		base = String(message)
	TranslationServer.set_locale(saved)
	return StringName(Pseudolocale.expand(base))
