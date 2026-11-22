extends Node

var _openxr: OpenXRInterface
var _last_state: int = -1


func _session_name(state: int) -> String:
	match state:
		OpenXRInterface.SESSION_STATE_FOCUSED:
			return "FOCUSED"
		OpenXRInterface.SESSION_STATE_VISIBLE:
			return "VISIBLE"
	return str(state)


func _ready() -> void:
	_openxr = XRServer.find_interface("OpenXR") as OpenXRInterface
	if _openxr == null or not _openxr.is_initialized():
		push_warning("XR diagnóstico: OpenXR no está inicializado.")
		set_process(false)
		return

	print("XR sistema: ", _openxr.get_system_info())


func _process(_delta: float) -> void:
	var state: int = _openxr.get_session_state()
	if state != _last_state:
		_last_state = state
		print("XR sesión: ", _session_name(state))

