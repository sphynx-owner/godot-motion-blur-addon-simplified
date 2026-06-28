extends Node3D

var speed: float = 0


func _process(delta: float) -> void:
	speed += Input.get_axis("Decrease", "Increase") * 0.5
	
	rotation.x -= delta * speed


func _get_rotation_speed() -> float:
	return speed * get_process_delta_time()
