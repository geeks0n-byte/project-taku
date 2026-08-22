"""Apply edited English .txt files back into translations.csv (en column only)."""
import csv
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV_PATH = os.path.join(ROOT, "resources", "localization", "translations.csv")
EDIT_DIR = os.path.join(ROOT, "resources", "localization", "edit")

KEY_RE = re.compile(r"^\[([^\]]+)\]\s*$")


def parse_txt(path: str) -> dict[str, str]:
	out: dict[str, str] = {}
	current_key: str | None = None
	lines: list[str] = []

	def flush() -> None:
		nonlocal current_key, lines
		if current_key is not None:
			text = "\n".join(lines)
			# Strip one trailing newline Godot-style if present from block format
			if text.endswith("\n"):
				text = text[:-1]
			out[current_key] = text
		current_key = None
		lines = []

	with open(path, "r", encoding="utf-8") as f:
		for raw in f:
			line = raw.rstrip("\n")
			if line.startswith("#"):
				continue
			m = KEY_RE.match(line.strip())
			if m:
				flush()
				current_key = m.group(1)
				continue
			if current_key is None:
				continue
			if line == "" and not lines:
				continue
			if line == "" and lines and lines[-1] == "":
				continue
			lines.append(line)
	flush()
	return out


def load_all_edits() -> dict[str, str]:
	merged: dict[str, str] = {}
	if not os.path.isdir(EDIT_DIR):
		print(f"Missing edit dir: {EDIT_DIR}")
		sys.exit(1)
	for name in sorted(os.listdir(EDIT_DIR)):
		if not name.endswith(".txt") or name == "README.txt":
			continue
		path = os.path.join(EDIT_DIR, name)
		parsed = parse_txt(path)
		for key, text in parsed.items():
			if key in merged and merged[key] != text:
				print(f"Warning: duplicate key {key} in {name} (last wins)")
			merged[key] = text
	return merged


def main() -> None:
	edits = load_all_edits()
	if not edits:
		print("No [KEY] blocks found in edit/*.txt")
		sys.exit(1)

	with open(CSV_PATH, "r", encoding="utf-8", newline="") as f:
		rows = list(csv.reader(f))
	if not rows:
		print("Empty CSV")
		sys.exit(1)

	header = rows[0]
	if len(header) < 2 or header[1] != "en":
		print("Expected second column to be 'en'")
		sys.exit(1)

	updated = 0
	missing: list[str] = []
	for row in rows[1:]:
		if not row or not row[0].strip():
			continue
		key = row[0].strip()
		if key in edits:
			while len(row) < len(header):
				row.append("")
			if row[1] != edits[key]:
				row[1] = edits[key]
				updated += 1

	csv_keys = {r[0].strip() for r in rows[1:] if r and r[0].strip()}
	for key in edits:
		if key not in csv_keys:
			missing.append(key)

	with open(CSV_PATH, "w", encoding="utf-8", newline="") as f:
		writer = csv.writer(f, lineterminator="\n")
		writer.writerows(rows)

	print(f"Updated {updated} English strings in translations.csv")
	if missing:
		print(f"Warning: {len(missing)} keys in txt not in CSV: {', '.join(missing[:10])}")


if __name__ == "__main__":
	main()
