@abstract
class_name NodeFrameInfo
extends Resource

@export_storage var frame: int = 0

@export_storage var state: Dictionary[String, Variant]


func _init(node: Node = null, current_frame: int = 0) -> void:
	if node == null:
		return
	
	_capture_node_frame_info(node)
	frame = current_frame


static func should_capture(node: Node, past_frame_info: NodeFrameInfo) -> bool:
	return false


@abstract func recreate_frame(node: Node) -> void

@abstract func _capture_node_frame_info(node: Node) -> void
