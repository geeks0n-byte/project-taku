




extends RefCounted

static var _mocks: Dictionary = {}

static func get_mock_plugin(plugin_name: String) -> Object:
	if _mocks.has(plugin_name):
		return _mocks[plugin_name]

	var mock_instance: Object = null

	match plugin_name:
		"PoingGodotAdMob":
			var PluginScript = preload("res://addons/admob/internal/mock/mock_mobile_ads_plugin.gd")
			mock_instance = PluginScript.new()
		"PoingGodotAdMobAdView":
			var PluginScript = preload("res://addons/admob/internal/mock/mock_ad_view_plugin.gd")
			mock_instance = PluginScript.new()
		"PoingGodotAdMobNativeOverlayAd":
			var PluginScript = preload("res://addons/admob/internal/mock/mock_native_overlay_ad_plugin.gd")
			mock_instance = PluginScript.new()
		"PoingGodotAdMobAdSize":
			var PluginScript = preload("res://addons/admob/internal/mock/mock_ad_size_plugin.gd")
			mock_instance = PluginScript.new()
		"PoingGodotAdMobInterstitialAd":
			var PluginScript = preload("res://addons/admob/internal/mock/mock_interstitial_ad_plugin.gd")
			mock_instance = PluginScript.new()
		"PoingGodotAdMobRewardedAd":
			var PluginScript = preload("res://addons/admob/internal/mock/mock_rewarded_ad_plugin.gd")
			mock_instance = PluginScript.new()
		"PoingGodotAdMobRewardedInterstitialAd":
			var PluginScript = preload("res://addons/admob/internal/mock/mock_rewarded_interstitial_ad_plugin.gd")
			mock_instance = PluginScript.new()
		"PoingGodotAdMobAppOpenAd":
			var PluginScript = preload("res://addons/admob/internal/mock/mock_app_open_ad_plugin.gd")
			mock_instance = PluginScript.new()

	if mock_instance:
		_mocks[plugin_name] = mock_instance
		if mock_instance is Node:
			var main_loop := Engine.get_main_loop()
			if main_loop and main_loop is SceneTree:
				(main_loop as SceneTree).root.add_child.call_deferred(mock_instance)

	return mock_instance
