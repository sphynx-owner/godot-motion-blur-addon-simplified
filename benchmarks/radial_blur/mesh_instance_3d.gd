@tool
extends MeshInstance3D


func _process(delta: float) -> void:
	rotation.x += delta * 10
