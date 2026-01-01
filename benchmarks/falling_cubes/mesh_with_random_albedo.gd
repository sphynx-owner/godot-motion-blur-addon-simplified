@tool
extends MeshInstance3D


func _ready() -> void:
	var material = get_surface_override_material(0)
	material.albedo_color = Color(randf(), randf(), randf())
