class_name NodeRecord
extends Resource

# The initial state of a node, used to recreate it
@export_storage var node_initial_state: Dictionary[String, Variant]

@export_storage var spawn_frame: int = 0
@export_storage var despawn_frame: int = 0

## Records of all important information in a node's life
## ordered by the frame in which they were captured
@export_storage var recorded_info: Array[Variant]

@export_storage var recorded_transform_info: PackedByteArray


static func can_record_node(node: Node) -> bool:
	return node is MeshInstance3D


func capture_node_initial_state(node: Node, current_frame: int) -> void:
	if node is MeshInstance3D:
		node_initial_state = MeshInstance3DInitialState.capture_node_initial_state(node)
	
	spawn_frame = current_frame


func capture_node_frame_info(node: Node) -> void:
	capture_node_transform(node)
	
	#if node is Node3D:
		#recorded_info.append(Node3DFrameInfo.capture_node_frame_info(node))


func close_node_record(current_frame: int) -> void:
	despawn_frame = current_frame


func recreate_node() -> Node:
	return MeshInstance3DInitialState.recreate_node(node_initial_state)


func recreate_frame(node: Node, current_frame: int) -> void:
	recreate_node_transform(node, current_frame)
	#Node3DFrameInfo.recreate_frame(node, recorded_info[current_frame - spawn_frame])


func capture_node_transform(node: Node) -> void:
	var offset: int = recorded_transform_info.size()
	
	recorded_transform_info.resize(offset + 4 * 12)
	
	var global_transform: Transform3D = node.global_transform
	
	recorded_transform_info.encode_float(offset, global_transform.basis.x.x)
	offset += 4
	recorded_transform_info.encode_float(offset, global_transform.basis.x.y)
	offset += 4
	recorded_transform_info.encode_float(offset, global_transform.basis.x.z)
	offset += 4
	recorded_transform_info.encode_float(offset, global_transform.basis.y.x)
	offset += 4
	recorded_transform_info.encode_float(offset, global_transform.basis.y.y)
	offset += 4
	recorded_transform_info.encode_float(offset, global_transform.basis.y.z)
	offset += 4
	recorded_transform_info.encode_float(offset, global_transform.basis.z.x)
	offset += 4
	recorded_transform_info.encode_float(offset, global_transform.basis.z.y)
	offset += 4
	recorded_transform_info.encode_float(offset, global_transform.basis.z.z)
	offset += 4
	recorded_transform_info.encode_float(offset, global_transform.origin.x)
	offset += 4
	recorded_transform_info.encode_float(offset, global_transform.origin.y)
	offset += 4
	recorded_transform_info.encode_float(offset, global_transform.origin.z)



func recreate_node_transform(node: Node, current_frame: int) -> void:
	var offset: int = (current_frame - spawn_frame) * 4 * 12
	
	node.global_transform = Transform3D(
		Vector3(
			recorded_transform_info.decode_float(offset + 0 * 4),
			recorded_transform_info.decode_float(offset + 1 * 4),
			recorded_transform_info.decode_float(offset + 2 * 4),
		),
		Vector3(
			recorded_transform_info.decode_float(offset + 3 * 4),
			recorded_transform_info.decode_float(offset + 4 * 4),
			recorded_transform_info.decode_float(offset + 5 * 4),
		),
		Vector3(
			recorded_transform_info.decode_float(offset + 6 * 4),
			recorded_transform_info.decode_float(offset + 7 * 4),
			recorded_transform_info.decode_float(offset + 8 * 4),
		),
		Vector3(
			recorded_transform_info.decode_float(offset + 9 * 4),
			recorded_transform_info.decode_float(offset + 10 * 4),
			recorded_transform_info.decode_float(offset + 11 * 4),
		)
	)
