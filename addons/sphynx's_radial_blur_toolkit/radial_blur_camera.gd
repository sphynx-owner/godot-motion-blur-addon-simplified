@tool
extends Camera3D

func _process(delta: float) -> void:
	var camera: Camera3D = null
	
	if Engine.is_editor_hint():
		camera = \
		EditorInterface.get_edited_scene_root().get_window().get_viewport().get_camera_3d()
	else:
		camera = get_parent().get_parent().get_viewport().get_camera_3d()
	
	if !camera:
		return
	
	global_transform = camera.global_transform
