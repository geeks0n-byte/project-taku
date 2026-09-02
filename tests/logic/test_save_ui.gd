extends RefCounted

const LogicTestRunner := preload("res://tests/logic_test_runner.gd")

static func run(r: LogicTestRunner) -> void:
	_test_font_locale_policy(r)
	_test_save_migration_v1_to_v2(r)
	_test_save_migration_v2_to_v3(r)
	_test_save_migration_v3_to_v4(r)
	_test_safe_insets(r)
	_test_wide_ui_cap(r)
	_test_pseudolocale(r)

static func _approx4(r: LogicTestRunner, got: Vector4, expected: Vector4, name: String) -> void:
	r.ok(
		is_equal_approx(got.x, expected.x)
		and is_equal_approx(got.y, expected.y)
		and is_equal_approx(got.z, expected.z)
		and is_equal_approx(got.w, expected.w),
		name
	)

static func _test_font_locale_policy(r: LogicTestRunner) -> void:
	TranslationServer.set_locale("en")
	r.ok(HudFonts.uses_pixel_font(), "fonts: en uses pixel")
	TranslationServer.set_locale("ka")
	r.ok(not HudFonts.uses_pixel_font(), "fonts: ka uses default")
	TranslationServer.set_locale("uk")
	r.ok(not HudFonts.uses_pixel_font(), "fonts: uk uses default")
	TranslationServer.set_locale("en")

static func _test_save_migration_v1_to_v2(r: LogicTestRunner) -> void:
	const Migration := preload("res://scripts/save_migration.gd")
	var cfg := ConfigFile.new()
	cfg.set_value("Progression", "max_unlocked_level", 3)
	cfg.set_value("Progression", "current_language", "en")
	cfg.set_value("Progression", "level_star_bits", {1: 7, 2: 4})
	Migration.migrate_config(cfg, 1)
	var bits = cfg.get_value("Progression", "level_star_bits", {})
	r.ok(typeof(bits) == TYPE_DICTIONARY, "migrate: bits dict")
	r.ok(bits.has("1") and int(bits["1"]) == 7, "migrate: key 1 stringified")
	r.ok(bits.has("2") and int(bits["2"]) == 4, "migrate: key 2 stringified")
	r.ok(int(Migration.FORMAT_VERSION) >= 2, "migrate: format version is 2+")

static func _test_save_migration_v2_to_v3(r: LogicTestRunner) -> void:
	const Migration := preload("res://scripts/save_migration.gd")
	var empty_cfg := ConfigFile.new()
	empty_cfg.set_value("Progression", "max_unlocked_level", 20)
	Migration.migrate_config(empty_cfg, 2)
	var empty_seen = empty_cfg.get_value("Achievements", "seen", {})
	r.ok(empty_seen.is_empty(), "migrate v3: empty unlocks leave seen empty")
	var seeded_cfg := ConfigFile.new()
	seeded_cfg.set_value("Achievements", "unlocked", {"first_clear": 100, "clears_bronze": 101})
	Migration.migrate_config(seeded_cfg, 2)
	var seeded_seen: Dictionary = seeded_cfg.get_value("Achievements", "seen", {})
	r.ok(seeded_seen.has("first_clear"), "migrate v3: pre-existing unlock marked seen")
	r.ok(seeded_seen.has("clears_bronze"), "migrate v3: all pre-existing unlocks marked seen")
	r.ok(int(Migration.FORMAT_VERSION) >= 3, "migrate: format version is 3+")


static func _test_save_migration_v3_to_v4(r: LogicTestRunner) -> void:
	const Migration := preload("res://scripts/save_migration.gd")
	var cfg := ConfigFile.new()
	cfg.set_value("Progression", "max_unlocked_level", 75)
	cfg.set_value("Progression", "level_star_bits", {"15": 7, "74": 4})
	cfg.set_value("Progression", "levels_unseen", {"16": true})
	cfg.set_value("Progression", "completed_tutorial_scripts", ["level_1"])
	cfg.set_value("Achievements", "rules_open_levels", {"15": true, "20": true})
	cfg.set_value(
		"Session",
		"data",
		{
			"level_path": "res://levels/easy/level_15.tres",
			"level_number": 15,
		}
	)
	Migration.migrate_config(cfg, 3)
	r.ok(int(cfg.get_value("Progression", "max_unlocked_level", 0)) == 61, "migrate v4: max unlock remapped")
	var bits: Dictionary = cfg.get_value("Progression", "level_star_bits", {})
	r.ok(bits.has("1") and int(bits["1"]) == 7, "migrate v4: star bits key 15 -> 1")
	r.ok(bits.has("60") and int(bits["60"]) == 4, "migrate v4: star bits key 74 -> 60")
	var unseen: Dictionary = cfg.get_value("Progression", "levels_unseen", {})
	r.ok(unseen.has("2"), "migrate v4: unseen key 16 -> 2")
	var scripts: Array = cfg.get_value("Progression", "completed_tutorial_scripts", [])
	r.ok(scripts.has("level_00"), "migrate v4: tutorial script id remapped")
	var rules: Dictionary = cfg.get_value("Achievements", "rules_open_levels", {})
	r.ok(rules.has("1") and rules.has("6"), "migrate v4: rules_open_levels remapped")
	var session: Dictionary = cfg.get_value("Session", "data", {})
	r.ok(
		str(session.get("level_path", "")) == "res://levels/easy/level_01.tres",
		"migrate v4: session path remapped"
	)
	r.ok(int(session.get("level_number", -1)) == 1, "migrate v4: session level_number remapped")
	r.ok(int(Migration.FORMAT_VERSION) >= 4, "migrate: format version is 4+")

static func _test_safe_insets(r: LogicTestRunner) -> void:
	var none := SafeInsets.margins_from(
		Rect2(0, 0, 1080, 1920), Vector2(1080, 1920), Vector2.ZERO, Vector2(1080, 1920)
	)
	_approx4(r, none, Vector4.ZERO, "safe: no inset when safe covers the window")
	var empty := SafeInsets.margins_from(
		Rect2(0, 0, 1080, 1920), Vector2.ZERO, Vector2.ZERO, Vector2(1080, 1920)
	)
	_approx4(r, empty, Vector4.ZERO, "safe: zero window size is empty insets")
	var bars := SafeInsets.margins_from(
		Rect2(0, 120, 1080, 1720), Vector2(1080, 1920), Vector2.ZERO, Vector2(1080, 1920)
	)
	_approx4(r, bars, Vector4(0, 120, 0, 80), "safe: 120 top / 80 bottom in viewport px")
	var scaled := SafeInsets.margins_from(
		Rect2(0, 160, 1440, 2240), Vector2(1440, 2560), Vector2.ZERO, Vector2(1080, 1920)
	)
	_approx4(r, scaled, Vector4(0, 120, 0, 120), "safe: screen insets scale into viewport")
	var shifted := SafeInsets.margins_from(
		Rect2(40, 160, 1000, 1700), Vector2(1080, 1920), Vector2(40, 40), Vector2(1080, 1920)
	)
	_approx4(r, shifted, Vector4(0, 120, 80, 100), "safe: window origin subtracted from screen rect")
	r.ok(SafeInsets.padded_top(4.0) >= 4.0, "safe: padded_top never shrinks authored HUD top")
	r.ok(
		SafeInsets.padded_bottom_offset(-192.0) <= -192.0,
		"safe: padded_bottom_offset only grows the bottom reserve"
	)
	r.ok(SafeInsets.extra_top(4.0) >= 0.0, "safe: extra_top is non-negative")

static func _test_wide_ui_cap(r: LogicTestRunner) -> void:
	r.ok(is_equal_approx(HudLayout.extra_side_inset_for_cap(1032.0, 1032.0), 0.0), "wide-cap: phone width is no-op")
	r.ok(is_equal_approx(HudLayout.extra_side_inset_for_cap(1031.0, 1032.0), 0.0), "wide-cap: slightly narrow is no-op")
	r.ok(is_equal_approx(HudLayout.extra_side_inset_for_cap(2032.0, 1032.0), 500.0), "wide-cap: tablet splits extra")
	r.ok(is_equal_approx(HudLayout.UI_PHONE_CONTENT_WIDTH, 1032.0), "wide-cap: phone content is 1080-48")
	r.ok(is_equal_approx(HudLayout.UI_PHONE_EDITOR_ROW_WIDTH, 1040.0), "wide-cap: editor row is 1080-40")
	r.ok(is_equal_approx(HudLayout.extra_side_inset_for_cap(1872.0, 1032.0), 420.0), "wide-cap: status wrap inset on 1920")
	r.ok(is_equal_approx(HudLayout.extra_side_inset_for_cap(1072.0, 1072.0), 0.0), "wide-cap: editor status phone is no-op")
	r.ok(HudLayout.grid_row_pad_count(12, 3) == 0, "grid-pad: full page needs none")
	r.ok(HudLayout.grid_row_pad_count(5, 3) == 1, "grid-pad: custom leftover 5")
	r.ok(HudLayout.grid_row_pad_count(1, 3) == 2, "grid-pad: single leftover")
	r.ok(HudLayout.grid_row_pad_count(0, 3) == 0, "grid-pad: empty is none")
	r.ok(HudLayout.grid_row_pad_count(11, 3) == 1, "grid-pad: eleven needs one")
	var phone := Vector2(1080.0, 1920.0)
	var pad := 1.35
	var tile := phone * pad
	r.ok(is_equal_approx(maxf(tile.x / 1080.0, tile.y / 1920.0), 1.35), "bg-scale: phone tex is 1.35")
	var wide_tile := Vector2(1920.0, 1920.0) * pad
	r.ok(not is_equal_approx(maxf(wide_tile.x / 1080.0, wide_tile.y / 1920.0), 1.35), "bg-scale: wider base would zoom")
	var tablet_vp := Vector2(1440.0, 1920.0)
	var cover := phone * pad
	r.ok(is_equal_approx(cover.x, 1080.0 * 1.35), "bg-cover: width stays 1080*1.35 on 1440 viewport")
	r.ok(not is_equal_approx(cover.x, tablet_vp.x), "bg-cover: not live 1440")
	var spawn_x := tablet_vp.x + 64.0 + 50.0
	r.ok(spawn_x > tablet_vp.x, "bg-spawn: start x is off the live window")
	var phone_side := GameConstants.android_splash_icon_side_px(phone)
	r.ok(absf(phone_side - 288.0 * (1080.0 / 411.0)) < 1.0, "boot-splash: 288dp side on phone")
	r.ok(
		absf(GameConstants.android_ui_density(1080.0) - 1080.0 / 411.0) < 0.01,
		"boot-splash: headless uses viewport density",
	)
	var layout := GameConstants.boot_splash_icon_layout(Rect2(Vector2.ZERO, phone))
	var tile_px: float = layout["tile_px"]
	r.ok(absf(tile_px - 16.0 * phone_side / 64.0) < 0.05, "boot-splash: tile px tracks icon side")
	r.ok(
		absf(GameConstants.boot_splash_tile_sprite_scale(tile_px, 120.0) - tile_px / 120.0) < 0.05,
		"boot-splash: tile sprite scale fills 16px cell",
	)
	var visible_px := GameConstants.boot_splash_tile_visible_px(tile_px)
	var gap_px := (17.0 * phone_side / 64.0) - visible_px
	r.ok(absf(gap_px - 3.0 * phone_side / 64.0) < 0.05, "boot-splash: 3px gap between visible tiles")
	r.ok(tile_px > 120.0 and tile_px < 260.0, "boot-splash: tile px between old wrong extremes")
	r.ok(
		is_equal_approx(
			HudLayout.page_nav_bottom_inset(true),
			GameConstants.SCREEN_PAGE_NAV_BOTTOM_INSET + GameConstants.AD_BANNER_RESERVE
		),
		"page-nav: menu banner reserve stacks on base inset"
	)
	r.ok(
		HudLayout.page_nav_content_bottom_offset(true)
		< HudLayout.page_nav_content_bottom_offset(false),
		"page-nav: banner reserve pushes content higher"
	)


static func _test_pseudolocale(r: LogicTestRunner) -> void:
	var expanded := Pseudolocale.expand("PLAY")
	r.ok(expanded.begins_with("⟦"), "pseudolocale: wraps with brackets")
	r.ok(expanded.length() > 4, "pseudolocale: expands text")
	r.ok(Pseudolocale.LOCALE == "qa", "pseudolocale: qa locale supported")
