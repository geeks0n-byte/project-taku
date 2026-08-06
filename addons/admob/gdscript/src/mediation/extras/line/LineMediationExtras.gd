




class_name LineMediationExtras
extends MediationExtras

const ENABLE_AD_SOUND_KEY := "ENABLE_AD_SOUND_KEY"

var enable_ad_sound: bool:
	set(value):
		extras[ENABLE_AD_SOUND_KEY] = value


func _get_android_mediation_extra_class_name() -> String:
	return "com.poingstudios.godot.admob.mediation.line.LineExtrasBuilder"


func _get_ios_mediation_extra_class_name() -> String:
	return "LinePoingExtrasBuilder"
