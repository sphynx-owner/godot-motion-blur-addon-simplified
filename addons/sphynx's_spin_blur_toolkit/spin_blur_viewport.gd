@tool
class_name SpinBlurViewport
extends SubViewport

var parent_viewport: Viewport


func _ready() -> void:
	# So that the viewport's view does not lag a frame behind the reference camera
	process_priority = 1


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		size = EditorInterface.get_editor_viewport_3d().size
		
	else:
		size = parent_viewport.size
