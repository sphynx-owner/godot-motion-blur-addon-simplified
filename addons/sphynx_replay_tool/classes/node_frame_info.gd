@abstract
class_name NodeFrameInfo
extends Resource


static func should_capture(node: Node, past_frame_info: NodeFrameInfo) -> bool:
	return false


static func recreate_frame(node: Node, state: Variant) -> void:
	pass

static func capture_node_frame_info(node: Node) -> Variant:
	return {}
