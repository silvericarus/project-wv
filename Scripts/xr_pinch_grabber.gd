extends Node3D

enum PendingAction { NONE, GRAB, RELEASE, CANCEL }

@export_range(0.02, 0.3, 0.01) var grab_radius: float = 0.12
@export_flags_3d_physics var grab_mask: int = 2

var _hand: XRNode3D
var _origin: XROrigin3D
var _openxr: OpenXRInterface
var _held_body: XRGrabbable
var _reach_shape: SphereShape3D
var _pending_action: PendingAction = PendingAction.NONE


func _release(cancelled: bool) -> void:
	if is_instance_valid(_held_body):
		if _held_body.release(self, cancelled):
			print(_hand.name, ": objeto soltado", " (cancelado)" if cancelled else "")
	_held_body = null


func _update_anchor() -> bool:
	if _openxr == null or not _openxr.is_initialized():
		return false
	if _openxr.get_session_state() != OpenXRInterface.SESSION_STATE_FOCUSED:
		return false
	var hand_tracker := XRServer.get_tracker(_hand.tracker) as XRHandTracker
	if hand_tracker == null or not hand_tracker.has_tracking_data:
		return false
	if hand_tracker.hand_tracking_source != XRHandTracker.HAND_TRACKING_SOURCE_UNOBSTRUCTED:
		return false

	var required: int = XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID | XRHandTracker.HAND_JOINT_FLAG_POSITION_TRACKED
	var thumb_flags: int = hand_tracker.get_hand_joint_flags(XRHandTracker.HAND_JOINT_THUMB_TIP)
	var index_flags: int = hand_tracker.get_hand_joint_flags(XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP)
	if (thumb_flags & required) != required or (index_flags & required) != required:
		return false

	var thumb := hand_tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_THUMB_TIP).origin
	var index := hand_tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP).origin
	global_transform = Transform3D(_hand.global_basis.orthonormalized(), _origin.to_global((thumb + index) * 0.5))
	return true


func _try_grab_nearby() -> void:
	if is_instance_valid(_held_body):
		return
	_reach_shape.radius = grab_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _reach_shape
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collision_mask = grab_mask
	query.collide_with_areas = false

	var nearest: XRGrabbable
	var nearest_distance: float = INF
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 32):
		var body := hit.get("collider") as XRGrabbable
		if body == null or body.is_held() or body.freeze:
			continue
		var distance := global_position.distance_squared_to(body.global_position)
		if distance < nearest_distance:
			nearest = body
			nearest_distance = distance

	if nearest != null and nearest.try_grab(self):
		_held_body = nearest
		print(_hand.name, ": objeto agarrado: ", nearest.name)


func _on_pinch_started() -> void:
	_pending_action = PendingAction.GRAB


func _on_pinch_released() -> void:
	_pending_action = PendingAction.RELEASE


func _on_pinch_cancelled() -> void:
	_pending_action = PendingAction.CANCEL


func _ready() -> void:
	_hand = get_parent() as XRNode3D
	if _hand == null or not _hand.has_signal("pinch_started"):
		push_error("Grabber debe ser hijo de una mano con xr_hand_pinch.gd.")
		set_physics_process(false)
		return
	_origin = _hand.get_parent() as XROrigin3D
	if _origin == null:
		push_error("La mano debe ser hija directa de XROrigin3D.")
		set_physics_process(false)
		return

	_reach_shape = SphereShape3D.new()
	_openxr = XRServer.find_interface("OpenXR") as OpenXRInterface
	_hand.connect("pinch_started", _on_pinch_started)
	_hand.connect("pinch_released", _on_pinch_released)
	_hand.connect("pinch_cancelled", _on_pinch_cancelled)


func _physics_process(_delta: float) -> void:
	var action := _pending_action
	_pending_action = PendingAction.NONE
	if not _update_anchor():
		_release(true)
		return

	if is_instance_valid(_held_body) and not _held_body.is_held_by(self):
		_held_body = null

	match action:
		PendingAction.CANCEL:
			_release(true)
		PendingAction.RELEASE:
			_release(false)
		PendingAction.GRAB:
			_try_grab_nearby()


func _exit_tree() -> void:
	_release(true)

