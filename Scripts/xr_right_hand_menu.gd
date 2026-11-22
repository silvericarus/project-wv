extends Node3D

@export var right_controller: XRController3D
@export var right_hand: XRNode3D
@export var camera: XRCamera3D
@export var toggle_action: StringName = &"by_button"
@export var hand_offset: Vector3 = Vector3(0.0, 0.18, 0.0)

@onready var display: MeshInstance3D = $Display
@onready var menu_viewport: SubViewport = $MenuViewport

var _opened: bool = false
var _openxr: OpenXRInterface


func _session_focused() -> bool:
	return _openxr != null and _openxr.is_initialized() and _openxr.get_session_state() == OpenXRInterface.SESSION_STATE_FOCUSED


func _get_right_anchor() -> Node3D:
	if right_hand != null:
		var hand_tracker := XRServer.get_tracker(right_hand.tracker) as XRHandTracker
		if hand_tracker != null and hand_tracker.has_tracking_data and right_hand.get_has_tracking_data():
			var optical := hand_tracker.hand_tracking_source == XRHandTracker.HAND_TRACKING_SOURCE_UNOBSTRUCTED
			if get_parent().has_method("_has_hand_data"):
				optical = bool(get_parent().call("_has_hand_data", right_hand))
			if optical:
				return right_hand

	if right_controller.get_is_active() and right_controller.get_has_tracking_data():
		return right_controller
	return null


func _refresh_menu() -> void:
	var anchor := _get_right_anchor()
	visible = _opened and _session_focused() and anchor != null
	menu_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
	if not visible:
		return

	global_position = anchor.global_position + camera.global_basis.orthonormalized() * hand_offset
	var toward_camera := camera.global_position - global_position
	if toward_camera.length_squared() > 0.000001:
		var up := Vector3.UP
		if absf(toward_camera.normalized().dot(up)) > 0.98:
			up = camera.global_basis.z
		look_at(camera.global_position, up, true)


func _on_button_pressed(action_name: String) -> void:
	if StringName(action_name) != toggle_action or not _session_focused():
		return
	_opened = not _opened
	_refresh_menu()
	print("Menú derecho: ", "abierto" if _opened else "cerrado")


func _ready() -> void:
	hide()
	if right_controller == null or camera == null:
		push_error("Asigna Right Controller y Camera en RightHandMenu.")
		set_process(false)
		return

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = menu_viewport.get_texture()
	display.material_override = material

	_openxr = XRServer.find_interface("OpenXR") as OpenXRInterface
	right_controller.button_pressed.connect(_on_button_pressed)
	_refresh_menu()


func _process(_delta: float) -> void:
	_refresh_menu()

