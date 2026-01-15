@tool
extends MeshInstance3D


func _process(delta: float) -> void:
	position.x = 10 * sin(Time.get_ticks_msec() / 1000.0 * 30)
