extends XROrigin3D

@export var accept_unknown_hand_source: bool = true

@onready var left_controller: XRController3D = $LeftHand
@onready var right_controller: XRController3D = $RightHand
@onready var left_hand: XRNode3D = $TrackerLeftHand
@onready var right_hand: XRNode3D = $TrackerRightHand

@onready var left_controller_visual: Node3D = $LeftHand/ControllerVisual
@onready var right_controller_visual: Node3D = $RightHand/ControllerVisual
@onready var left_hand_marker: Node3D = $TrackerLeftHand/HandMarker
@onready var right_hand_marker: Node3D = $TrackerRightHand/HandMarker

var _last_status: String = ""


func _has_hand_data(hand: XRNode3D) -> bool:
	var hand_tracker := XRServer.get_tracker(hand.tracker) as XRHandTracker
	if hand_tracker == null or not hand_tracker.has_tracking_data:
		return false

	if hand_tracker.hand_tracking_source == XRHandTracker.HAND_TRACKING_SOURCE_UNOBSTRUCTED:
		return true

	if hand_tracker.hand_tracking_source == XRHandTracker.HAND_TRACKING_SOURCE_UNKNOWN:
		return accept_unknown_hand_source

	return false


func _describe_hand(hand: XRNode3D) -> String:
	var hand_tracker := XRServer.get_tracker(hand.tracker) as XRHandTracker
	if hand_tracker == null:
		return "%s: tracker ausente" % hand.name

	return "%s: datos=%s pose=%s fuente=%d" % [
		hand.name,
		hand_tracker.has_tracking_data,
		hand.get_has_tracking_data(),
		hand_tracker.hand_tracking_source
	]


func _update_visuals() -> void:
	var left_has_data := _has_hand_data(left_hand)
	var right_has_data := _has_hand_data(right_hand)
	var using_hands := left_has_data or right_has_data

	left_hand_marker.visible = left_has_data and left_hand.get_has_tracking_data()
	right_hand_marker.visible = right_has_data and right_hand.get_has_tracking_data()

	left_controller_visual.visible = not using_hands and left_controller.get_is_active() and left_controller.get_has_tracking_data()
	right_controller_visual.visible = not using_hands and right_controller.get_is_active() and right_controller.get_has_tracking_data()

	var mode_name := "MANOS" if using_hands else "MANDOS"
	var status := "%s | %s | modo=%s" % [
		_describe_hand(left_hand),
		_describe_hand(right_hand),
		mode_name
	]
	if status != _last_status:
		_last_status = status
		print(status)


func _ready() -> void:
	left_hand.tracker = &"/user/hand_tracker/left"
	right_hand.tracker = &"/user/hand_tracker/right"
	for hand: XRNode3D in [left_hand, right_hand]:
		hand.pose = &"default"
		hand.show_when_tracked = true

	var openxr := XRServer.find_interface("OpenXR") as OpenXRInterface
	print("Hand Tracking activado en ajustes: ", ProjectSettings.get_setting("xr/openxr/extensions/hand_tracking", false))
	if openxr != null and openxr.is_initialized():
		print("Hand Tracking disponible en OpenXR: ", openxr.is_hand_tracking_supported())

	_update_visuals()


func _process(_delta: float) -> void:
	_update_visuals()
