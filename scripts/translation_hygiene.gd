class_name TranslationHygiene
extends RefCounted
## Headless-safe checks for resources/localization/translations.csv.

const CSV_PATH := "res://resources/localization/translations.csv"
const SUPPORTED_LANGUAGES := ["en", "es", "de", "fr", "pl", "ka", "uk"]

static func _placeholder_count(text: String) -> int:
	var count := 0
	var i := 0
	while i < text.length():
		if text[i] == "%" and i + 1 < text.length():
			var next := text[i + 1]
			if next == "%":
				i += 2
				continue
			if next == "s" or next == "d" or next == "i" or next == "f":
				count += 1
				i += 2
				continue
		i += 1
	return count


## Returns human-readable problem strings; empty means the CSV passed.
static func audit(csv_path: String = CSV_PATH, locales: Array = SUPPORTED_LANGUAGES) -> Array[String]:
	var errors: Array[String] = []
	if not FileAccess.file_exists(csv_path):
		errors.append("translations.csv missing at %s" % csv_path)
		return errors
	var file := FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		errors.append("translations.csv unreadable at %s" % csv_path)
		return errors
	var headers: PackedStringArray = file.get_csv_line()
	if headers.size() < 2 or headers[0] != "keys":
		errors.append("translations.csv: first column must be 'keys'")
		file.close()
		return errors
	var expected := headers.size()
	var en_idx := headers.find("en")
	if en_idx < 0:
		errors.append("translations.csv missing 'en' column")
		file.close()
		return errors
	for code in locales:
		if not headers.has(code):
			errors.append("translations.csv missing locale column: %s" % code)
	var empty_cells := 0
	var rows := 0
	var placeholder_mismatches := 0
	const MAX_PLACEHOLDER_ERRORS := 10
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.is_empty():
			continue
		var key := String(row[0]).strip_edges()
		if key.is_empty() or key == "keys":
			continue
		rows += 1
		if row.size() != expected:
			errors.append("translations.csv: %s has %d cols, expected %d" % [key, row.size(), expected])
			continue
		var en_text := String(row[en_idx])
		var en_placeholders := _placeholder_count(en_text)
		for i in range(1, expected):
			if String(row[i]).is_empty():
				empty_cells += 1
			if i == en_idx:
				continue
			var locale_placeholders := _placeholder_count(String(row[i]))
			if locale_placeholders != en_placeholders:
				placeholder_mismatches += 1
				if placeholder_mismatches <= MAX_PLACEHOLDER_ERRORS:
					errors.append(
						"translations.csv: %s/%s placeholder mismatch (en=%d, %s=%d)"
						% [key, headers[i], en_placeholders, headers[i], locale_placeholders]
					)
	file.close()
	if empty_cells > 0:
		errors.append("translations.csv: %d empty cell(s) across %d keys" % [empty_cells, rows])
	if placeholder_mismatches > MAX_PLACEHOLDER_ERRORS:
		errors.append(
			"translations.csv: %d placeholder mismatches (first %d listed)"
			% [placeholder_mismatches, MAX_PLACEHOLDER_ERRORS]
		)
	return errors
