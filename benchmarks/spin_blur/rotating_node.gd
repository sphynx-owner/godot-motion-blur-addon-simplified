extends Node3D

var speed: float = 0


func _process(delta: float) -> void:
	speed += Input.get_axis("Decrease", "Increase") * delta * 10
	
	rotation.x += delta * speed
