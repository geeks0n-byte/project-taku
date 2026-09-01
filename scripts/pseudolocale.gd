class_name Pseudolocale
extends RefCounted
## Accent-expansion pseudolocale for layout QA (Microsoft qps-ploc style).

const LOCALE := "qa"

## Expands ASCII strings with diacritics and brackets to stress UI width.
static func expand(text: String) -> String:
	var raw := str(text)
	if raw.is_empty():
		return raw
	if raw.begins_with("⟦") and raw.ends_with("⟧"):
		return raw
	var out := PackedStringArray()
	out.append("⟦")
	for i in raw.length():
		var ch := raw[i]
		out.append(_expand_char(ch))
	out.append("⟧")
	return "".join(out)


static func _expand_char(ch: String) -> String:
	match ch:
		"a", "A":
			return "à" if ch == "a" else "À"
		"c", "C":
			return "ç" if ch == "c" else "Ç"
		"e", "E":
			return "ë" if ch == "e" else "Ë"
		"i", "I":
			return "ï" if ch == "i" else "Ï"
		"o", "O":
			return "ö" if ch == "o" else "Ö"
		"u", "U":
			return "ü" if ch == "u" else "Ü"
		_:
			return ch
