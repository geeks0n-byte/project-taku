
class_name AppOpenAdLoadCallback
extends RefCounted

var on_ad_loaded: Callable = func(_app_open_ad: AppOpenAd): pass

var on_ad_failed_to_load: Callable = func(_load_ad_error: LoadAdError): pass
