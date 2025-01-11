extends Node3D

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("ESC"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE else Input.MOUSE_MODE_VISIBLE
	$SphynxGuertinViewport.push_input(event, true)
	$KinoGuertinViewport.push_input(event, true)
