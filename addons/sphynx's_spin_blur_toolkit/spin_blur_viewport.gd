@tool
class_name SpinBlurViewport
extends SubViewport

var parent_viewport: Viewport


func _ready() -> void:
	# So that the viewport's view does not lag a frame behind the reference camera
	process_priority = 1


func _process(delta: float) -> void:
	var parent_viewport: Viewport
	
	if Engine.is_editor_hint():
		parent_viewport = EditorInterface.get_editor_viewport_3d()
	else:
		parent_viewport = get_viewport()
	
	if "size" in parent_viewport:
		size = parent_viewport.size
