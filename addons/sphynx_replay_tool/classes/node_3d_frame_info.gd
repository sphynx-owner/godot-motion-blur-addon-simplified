class_name Node3DFrameInfo
extends NodeFrameInfo


static func should_capture(node: Node, past_frame_info: NodeFrameInfo) -> bool:
	return node.global_transform != past_frame_info.state.global_transform


static func recreate_frame(node: Node, state: Variant) -> void:
	var serialized_transform: PackedFloat32Array = state
	
	node.global_transform = Transform3D(
		Vector3(
			serialized_transform[0],
			serialized_transform[1],
			serialized_transform[2],
		),
		Vector3(
			serialized_transform[3],
			serialized_transform[4],
			serialized_transform[5],
		),
		Vector3(
			serialized_transform[6],
			serialized_transform[7],
			serialized_transform[8],
		),
		Vector3(
			serialized_transform[9],
			serialized_transform[10],
			serialized_transform[11],
		)
	)


static func capture_node_frame_info(node: Node) -> Variant:
	var global_transform: Transform3D = node.global_transform
	
	var state: PackedFloat32Array = [
		global_transform.basis.x.x,
		global_transform.basis.x.y,
		global_transform.basis.x.z,
		global_transform.basis.y.x,
		global_transform.basis.y.y,
		global_transform.basis.y.z,
		global_transform.basis.z.x,
		global_transform.basis.z.y,
		global_transform.basis.z.z,
		global_transform.origin.x,
		global_transform.origin.y,
		global_transform.origin.z,
	]
	
	return state
