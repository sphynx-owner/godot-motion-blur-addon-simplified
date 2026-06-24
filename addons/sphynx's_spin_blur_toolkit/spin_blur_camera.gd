@tool
class_name SpinBlurCamera
extends Camera3D

var parent_viewport: Viewport


func _ready() -> void:
	# So that the viewport's view does not lag a frame behind the reference camera
	process_priority = 1


func _process(delta: float) -> void:
	var reference_camera: Camera3D
	
	if Engine.is_editor_hint():
		reference_camera = EditorInterface.get_editor_viewport_3d().get_camera_3d()
		
	else:
		reference_camera = parent_viewport.get_camera_3d()
	
	if !reference_camera:
		return
	
	reference_camera.cull_mask &= ~cull_mask
	
	global_transform = reference_camera.global_transform
	fov = reference_camera.fov
	projection = reference_camera.projection
