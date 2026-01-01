class_name Node3DFrameInfo
extends NodeFrameInfo


static func should_capture(node: Node, past_frame_info: NodeFrameInfo) -> bool:
	return node.global_transform != past_frame_info.state.global_transform


func recreate_frame(node: Node) -> void:
	node.global_transform = state.global_transform


func _capture_node_frame_info(node: Node) -> void:
	state.global_transform = node.global_transform
