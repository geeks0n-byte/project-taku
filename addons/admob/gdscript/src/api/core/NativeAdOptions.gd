
class_name NativeAdOptions

var media_aspect_ratio: NativeMediaAspectRatio.Values = NativeMediaAspectRatio.Values.UNKNOWN
var ad_choices_placement: AdChoicesPlacement.Values = AdChoicesPlacement.Values.TOP_RIGHT
var video_options: AdVideoOptions = AdVideoOptions.new()


func convert_to_dictionary() -> Dictionary:
	return {
		"media_aspect_ratio": media_aspect_ratio,
		"ad_choices_placement": ad_choices_placement,
		"video_options": video_options.convert_to_dictionary()
	}
