extends "xr_pinch_grabber.gd"

@export var grab_action: StringName = &"grip"
@export_range(0.0, 1.0, 0.01) var press_threshold: float = 0.7
@export_range(0.0, 1.0, 0.01) var release_threshold: float = 0.3

var _controller: XRController3D
var _squeezed: bool = false
var _needs_release: bool = true


func _optical_hands_active() -> bool:
	if _origin.has_method("_has_hand_data"):
		for child in _origin.get_children():
			if child is XRNode3D and not child is XRController3D:
				if bool(_origin.call("_has_hand_data", child)):
					return true
		return false

	for path in [&"/user/hand_tracker/left", &"/user/hand_tracker/right"]:
		var hand_tracker := XRServer.get_tracker(path) as XRHandTracker
		if hand_tracker != null and hand_tracker.has_tracking_data:
			if hand_tracker.hand_tracking_source == XRHandTracker.HAND_TRACKING_SOURCE_UNOBSTRUCTED:
				return true
	return false


func _update_anchor() -> bool:
	if _openxr == null or not _openxr.is_initialized():
		return false
	if _openxr.get_session_state() != OpenXRInterface.SESSION_STATE_FOCUSED:
		return false
	if not _controller.get_is_active() or not _controller.get_has_tracking_data():
		return false
	if _optical_hands_active():
		return false

	global_transform = _controller.global_transform.orthonormalized()
	return true


func _poll_grab(value: float) -> void:
	if _needs_release:
		if value <= release_threshold:
			_needs_release = false
		return

	if not _squeezed and value >= press_threshold:
		_squeezed = true
		_pending_action = PendingAction.GRAB
		print(_controller.name, ": agarre pulsado")
	elif _squeezed and value <= release_threshold:
		_squeezed = false
		_pending_action = PendingAction.RELEASE
		print(_controller.name, ": agarre liberado")


func _ready() -> void:
	_controller = get_parent() as XRController3D
	if _controller == null:
		push_error("El Grabber del mando debe ser hijo de un XRController3D.")
		set_physics_process(false)
		return
	_hand = _controller
	_origin = _controller.get_parent() as XROrigin3D
	if _origin == null:
		push_error("El XRController3D debe ser hijo directo de XROrigin3D.")
		set_physics_process(false)
		return
	if release_threshold >= press_threshold:
		push_error("Release Threshold debe ser menor que Press Threshold.")
		set_physics_process(false)
		return

	_reach_shape = SphereShape3D.new()
	_openxr = XRServer.find_interface("OpenXR") as OpenXRInterface


func _physics_process(delta: float) -> void:
	if not _update_anchor():
		_squeezed = false
		_needs_release = true
		_pending_action = PendingAction.CANCEL
	else:
		_poll_grab(_controller.get_float(grab_action))

	super._physics_process(delta)

