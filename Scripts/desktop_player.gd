extends CharacterBody3D

@export var walk_speed: float = 3.5
@export var mouse_sensitivity: float = 0.12
@export_range(1.0, 90.0, 1.0) var grab_rotation_step: float = 15.0
@export var cube_scene: PackedScene

@onready var camera: Camera3D = $Camera3D
@onready var reach: RayCast3D = $Camera3D/RayCast3D
@onready var reticle: ColorRect = $HUD/Reticle
@onready var tools_menu: PanelContainer = $HUD/ToolsMenu
@onready var modes: VBoxContainer = $HUD/ToolsMenu/Modes
@onready var shapes: VBoxContainer = $HUD/ToolsMenu/Shapes

var cube_requested: bool = false
var held_object: XRGrabbable

func _ready() -> void:
	reach.add_exception(self)
	modes.get_node("CreationButton").pressed.connect(_show_shapes.bind(true))
	shapes.get_node("BackButton").pressed.connect(_show_shapes.bind(false))
	shapes.get_node("CubeButton").pressed.connect(_on_cube_pressed)
	
	
func _physics_process(delta: float) -> void:
	var movement := Vector2.ZERO
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		movement = Input.get_vector(
			&"desktop_left", &"desktop_right",
			&"desktop_forward", &"desktop_back"
		)

	var direction := global_transform.basis * Vector3(movement.x, 0.0, movement.y)
	velocity.x = direction.x * walk_speed
	velocity.z = direction.z * walk_speed

	if not is_on_floor():
		velocity += get_gravity() * delta

	move_and_slide()
	
	if cube_requested:
		cube_requested = false
		_place_cube()
	
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_just_pressed(&"desktop_grab"):
		_toggle_grab()
		reach.force_raycast_update()
		var hit := reach.get_collider() as Node

		if hit == null:
			print("El rayo no toca nada. Target Position: ", reach.target_position)
		else:
			print("El rayo toca: ", hit.get_path(), " | Es XRGrabbable: ", hit is XRGrabbable)
	_update_reticle()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"desktop_tools"):
		tools_menu.visible = not tools_menu.visible
		if tools_menu.visible:
			_show_shapes(false)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return

	if tools_menu.visible:
		if event.is_action_pressed(&"ui_cancel"):
			tools_menu.hide()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(&"ui_cancel"):
		_release_held_object(true)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if not event.pressed or not is_instance_valid(held_object):
			return
		if not held_object.is_held_by(camera):
			return

		var direction: float
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				direction = 1.0
			MOUSE_BUTTON_WHEEL_DOWN:
				direction = -1.0
			_:
				return

		var axis := Vector3.LEFT
		if event.shift_pressed:
			axis = camera.global_basis.y.normalized()

		held_object.rotate_held(camera, axis, deg_to_rad(grab_rotation_step) * direction)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var motion: Vector2 = event.screen_relative * deg_to_rad(mouse_sensitivity)
		rotate_y(-motion.x)
		camera.rotation.x = clampf(
			camera.rotation.x - motion.y,
			deg_to_rad(-85.0),
			deg_to_rad(85.0)
		)


func _toggle_grab() -> void:
	if is_instance_valid(held_object) and held_object.is_held_by(camera):
		_release_held_object()
		return

	held_object = null
	reach.force_raycast_update()
	var target := reach.get_collider() as XRGrabbable

	if target != null and target.try_grab(camera):
		held_object = target


func _release_held_object(cancelled: bool = false) -> void:
	if is_instance_valid(held_object):
		held_object.release(camera, cancelled)
	held_object = null


func _update_reticle() -> void:
	reticle.visible = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if not reticle.visible:
		return

	reticle.color = Color.WHITE
	if is_instance_valid(held_object) and held_object.is_held_by(camera):
		return

	var target := reach.get_collider() as XRGrabbable
	if target != null and not target.freeze and not target.is_held():
		reticle.color = Color.LIGHT_GREEN


func _show_shapes(open: bool) -> void:
	modes.visible = not open
	shapes.visible = open

func _on_cube_pressed() -> void:
	tools_menu.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	cube_requested = true


func _place_cube() -> void:
	if cube_scene == null:
		push_warning("Asigna physics_cube.tscn al campo Cube Scene de DesktopPlayer.")
		return

	reach.force_raycast_update()
	if not reach.is_colliding() or reach.get_collision_normal().y < 0.99:
		print("Apunta a una superficie horizontal al alcance de la mira.")
		return

	var cube := cube_scene.instantiate() as XRGrabbable
	var collision := cube.get_node("CollisionShape3D") as CollisionShape3D
	var box := collision.shape as BoxShape3D
	var spawn_point := reach.get_collision_point() + Vector3.UP * (box.size.y * 0.5 + 0.01)

	var world := get_tree().current_scene as Node3D
	cube.position = world.to_local(spawn_point)
	world.add_child(cube)
