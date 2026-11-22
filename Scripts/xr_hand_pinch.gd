extends XRNode3D

signal pinch_started
signal pinch_released
signal pinch_cancelled

@export_range(0.005, 0.08, 0.001) var pinch_distance: float = 0.025
@export_range(0.005, 0.12, 0.001) var release_distance: float = 0.04
@export var rest_color: Color = Color(0.1, 0.7, 1.0)
@export var pinch_color: Color = Color(0.2, 1.0, 0.3)

@onready var marker: MeshInstance3D = $HandMarker

var _material: StandardMaterial3D
var _openxr: OpenXRInterface
var _pinching: bool = false
var _needs_open_hand: bool = true


func _set_pinching(value: bool) -> void:
	_pinching = value
	_material.albedo_color = pinch_color if value else rest_color


func _cancel_pinch() -> void:
	_needs_open_hand = true
	if _pinching:
		_set_pinching(false)
		print(name, ": pinza cancelada por pérdida de seguimiento o foco")
		pinch_cancelled.emit()


func _has_valid_fingers(hand_tracker: XRHandTracker) -> bool:
	if hand_tracker == null or not hand_tracker.has_tracking_data:
		return false
	if hand_tracker.hand_tracking_source != XRHandTracker.HAND_TRACKING_SOURCE_UNOBSTRUCTED:
		return false

	var required_flags: int = XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID | XRHandTracker.HAND_JOINT_FLAG_POSITION_TRACKED
	var thumb_flags: int = hand_tracker.get_hand_joint_flags(XRHandTracker.HAND_JOINT_THUMB_TIP)
	var index_flags: int = hand_tracker.get_hand_joint_flags(XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP)
	return (thumb_flags & required_flags) == required_flags and (index_flags & required_flags) == required_flags


func _update_pinch(hand_tracker: XRHandTracker) -> void:
	if not _has_valid_fingers(hand_tracker):
		_cancel_pinch()
		return

	var thumb_position := hand_tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_THUMB_TIP).origin
	var index_position := hand_tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP).origin
	var distance := thumb_position.distance_to(index_position)

	if _needs_open_hand:
		if distance >= release_distance:
			_needs_open_hand = false
		return

	if not _pinching and distance <= pinch_distance:
		_set_pinching(true)
		print(name, ": pinza iniciada")
		pinch_started.emit()
	elif _pinching and distance >= release_distance:
		_set_pinching(false)
		print(name, ": pinza liberada")
		pinch_released.emit()


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = _material
	_set_pinching(false)

	if release_distance <= pinch_distance:
		push_error("Release Distance debe ser mayor que Pinch Distance.")
		set_process(false)
		return

	_openxr = XRServer.find_interface("OpenXR") as OpenXRInterface


func _process(_delta: float) -> void:
	if _openxr == null or not _openxr.is_initialized():
		_cancel_pinch()
		return
	if _openxr.get_session_state() != OpenXRInterface.SESSION_STATE_FOCUSED:
		_cancel_pinch()
		return

	var hand_tracker := XRServer.get_tracker(tracker) as XRHandTracker
	_update_pinch(hand_tracker)

