extends Node3D

var xr_interface: XRInterface

func _setup_xr() -> void:
	xr_interface = XRServer.find_interface("OpenXR")

	if xr_interface == null:
		push_error("OpenXR no está disponible. Habilita XR > OpenXR > Enabled y reinicia el editor.")
		return

	if not xr_interface.is_initialized():
		push_error("OpenXR no se ha inicializado. Activa la sesión de PCVR y comprueba el proveedor OpenXR de Windows.")
		return

	get_viewport().use_xr = true
	print("OpenXR inicializado. Comprueba la imagen en el visor.")


func _enter_tree() -> void:
	var openxr := XRServer.find_interface("OpenXR")
	var desktop_player := get_node("DesktopPlayer") as CharacterBody3D
	var xr_origin := get_node("XROrigin3D") as XROrigin3D

	if openxr != null and openxr.is_initialized():
		desktop_player.free()
		_setup_xr()
		return

	get_viewport().use_xr = false
	desktop_player.position = xr_origin.position
	desktop_player.rotation.y = xr_origin.rotation.y
	xr_origin.free()
