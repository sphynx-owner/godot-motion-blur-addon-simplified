extends MeshInstance3D

@export var speed := 20.0


func _process(delta: float) -> void:
	rotation.x += delta * speed



func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_UP:
			speed += get_process_delta_time() * 50
		elif event.keycode == KEY_DOWN:
			speed -= get_process_delta_time() * 50
