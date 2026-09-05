#!/usr/bin/env bash
# Resolves or downloads the pinned Godot binary for Linux CI / dev shells.
# Prints the absolute executable path on stdout.
#
# Resolution order:
#   1. GODOT_EXE (when set and executable)
#   2. `godot` on PATH when --version matches GODOT_VERSION
#   3. Cached binary under GODOT_CI_CACHE_DIR
#   4. Download (GitHub Actions or GODOT_ALLOW_DOWNLOAD=1)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/tools/godot.env"
if [[ -f "$ROOT/tools/godot.local.env" ]]; then
	# shellcheck source=/dev/null
	source "$ROOT/tools/godot.local.env"
fi

linux_basename() {
	printf 'Godot_v%s-%s_linux.x86_64' "$GODOT_VERSION" "$GODOT_RELEASE"
}

cached_linux_path() {
	printf '%s/%s/%s' "$ROOT" "$GODOT_CI_CACHE_DIR" "$(linux_basename)"
}

godot_on_path_matches() {
	if ! command -v godot >/dev/null 2>&1; then
		return 1
	fi
	local ver
	ver="$(godot --version 2>/dev/null || true)"
	[[ "$ver" == *"$GODOT_VERSION"* ]]
}

resolve_existing() {
	if [[ -n "${GODOT_EXE:-}" && -x "$GODOT_EXE" ]]; then
		printf '%s\n' "$GODOT_EXE"
		return 0
	fi
	if godot_on_path_matches; then
		command -v godot
		return 0
	fi
	local cached
	cached="$(cached_linux_path)"
	if [[ -x "$cached" ]]; then
		printf '%s\n' "$cached"
		return 0
	fi
	return 1
}

download_linux() {
	local cache_dir name zip_url zip_path target
	cache_dir="$ROOT/$GODOT_CI_CACHE_DIR"
	name="$(linux_basename)"
	zip_url="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-${GODOT_RELEASE}/${name}.zip"
	zip_path="$cache_dir/godot.zip"
	target="$cache_dir/$name"
	mkdir -p "$cache_dir"
	curl -L --fail -o "$zip_path" "$zip_url"
	unzip -o "$zip_path" -d "$cache_dir"
	chmod +x "$target"
	rm -f "$zip_path"
	printf '%s\n' "$target"
}

if resolved="$(resolve_existing)"; then
	printf '%s\n' "$resolved"
	exit 0
fi

if [[ "${GITHUB_ACTIONS:-}" == "true" || "${GODOT_ALLOW_DOWNLOAD:-}" == "1" ]]; then
	download_linux
	exit 0
fi

echo "Godot ${GODOT_VERSION} not found. Set GODOT_EXE, install godot on PATH, cache under ${GODOT_CI_CACHE_DIR}, or set GODOT_ALLOW_DOWNLOAD=1." >&2
exit 1
