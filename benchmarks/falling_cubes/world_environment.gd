extends WorldEnvironment


func _ready() -> void:
	compositor.compositor_effects[1]._stencil_texture = compositor.compositor_effects[0].output_texture
