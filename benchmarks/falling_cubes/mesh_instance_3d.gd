extends MeshInstance3D

func _ready() -> void:
	get_surface_override_material(0).albedo_texture = $"../WorldEnvironment".compositor.compositor_effects[0].output_texture
