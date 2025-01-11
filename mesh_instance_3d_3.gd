@tool
extends MeshInstance3D

@export var velocity := 10.0
@export var direction := Vector3(1, 0, 0)
@export var frequency := PI

func _process(delta: float) -> void:
	global_position += sin(Time.get_ticks_msec() / 1000.0 * frequency) * velocity * delta * direction
