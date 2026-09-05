




class_name AdapterStatus

var latency: int
var initialization_state: InitializationState
var description: String

enum InitializationState { NOT_READY, READY }


func _init(p_latency: int, p_initialization_state: InitializationState, p_description: String) -> void:
	self.latency = p_latency
	self.initialization_state = p_initialization_state
	self.description = p_description
