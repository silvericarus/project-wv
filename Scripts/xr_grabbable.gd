class_name XRGrabbable
extends RigidBody3D

@export_range(1.0, 500.0) var position_stiffness: float = 180.0
@export_range(1.0, 100.0) var position_damping: float = 27.0
@export_range(1.0, 200.0) var max_acceleration: float = 80.0
@export_range(1.0, 30.0) var rotation_response: float = 12.0
@export_range(1.0, 30.0) var max_angular_speed: float = 8.0
@export_range(0.1, 3.0) var break_distance: float = 1.25

var _holder: WeakRef
var _hold_offset: Transform3D = Transform3D.IDENTITY


func _get_holder() -> Node3D:
	if _holder == null:
		return null
	return _holder.get_ref() as Node3D


func _drop(cancelled: bool) -> void:
	_holder = null
	if cancelled:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
	sleeping = false


func is_held() -> bool:
	return _get_holder() != null


func is_held_by(holder: Node3D) -> bool:
	return _get_holder() == holder


func try_grab(holder: Node3D) -> bool:
	if holder == null or freeze or is_held():
		return false
	_holder = weakref(holder)
	_hold_offset = holder.global_transform.affine_inverse() * global_transform
	sleeping = false
	return true


func release(holder: Node3D, cancelled: bool = false) -> bool:
	if not is_held_by(holder):
		return false
	_drop(cancelled)
	return true


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _holder == null:
		return

	var holder := _get_holder()
	if holder == null:
		_drop(true)
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		return

	var target := holder.global_transform * _hold_offset
	var position_error := target.origin - state.transform.origin
	if position_error.length() > break_distance:
		_drop(true)
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		return

	var acceleration := position_error * position_stiffness - state.linear_velocity * position_damping - state.total_gravity
	state.apply_central_force(acceleration.limit_length(max_acceleration) * mass)

	var difference := target.basis.orthonormalized() * state.transform.basis.orthonormalized().transposed()
	var rotation_error := difference.get_rotation_quaternion().normalized()
	if rotation_error.w < 0.0:
		rotation_error = Quaternion(-rotation_error.x, -rotation_error.y, -rotation_error.z, -rotation_error.w)
	state.angular_velocity = (rotation_error.get_axis() * rotation_error.get_angle() * rotation_response).limit_length(max_angular_speed)


func rotate_held(holder: Node3D, world_axis: Vector3, angle: float) -> void:
	if not is_held_by(holder):
		return

	var local_axis := (holder.global_basis.inverse() * world_axis).normalized()
	_hold_offset.basis = _hold_offset.basis.rotated(local_axis, angle)
