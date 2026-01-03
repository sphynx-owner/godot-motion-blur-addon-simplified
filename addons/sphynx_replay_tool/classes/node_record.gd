class_name NodeRecord
extends Resource

# The initial state of a node, used to recreate it
@export_storage var node_initial_state: Variant

@export_storage var spawn_frame: int = 0
@export_storage var despawn_frame: int = 0

## Records of all important information in a node's life
## ordered by the frame in which they were captured
@export_storage var recorded_info: Array[Variant]

@export_storage var recorded_transform_info: PackedByteArray


static func can_record_node(node: Node) -> bool:
	return node is MeshInstance3D or node is WorldEnvironment or node is Light3D


func capture_node_initial_state(node: Node, current_frame: int) -> void:
	if node is WorldEnvironment or node is Light3D:
		node_initial_state = WorldEnvironmentInitialState.capture_node_initial_state(node)
	if node is MeshInstance3D:
		node_initial_state = MeshInstance3DInitialState.capture_node_initial_state(node)
	
	spawn_frame = current_frame


func capture_node_frame_info(node: Node) -> void:
	if node is WorldEnvironment:
		return
	
	capture_node_transform(node)
	
	#if node is Node3D:
		#recorded_info.append(Node3DFrameInfo.capture_node_frame_info(node))


func close_node_record(current_frame: int) -> void:
	despawn_frame = current_frame


func recreate_node() -> Node:
	if node_initial_state is PackedScene:
		return WorldEnvironmentInitialState.recreate_node(node_initial_state)
	if node_initial_state is Array[Variant]:
		return MeshInstance3DInitialState.recreate_node(node_initial_state)
	
	return null


func recreate_frame(node: Node, current_frame: int) -> void:
	if node is WorldEnvironment:
		return
	
	recreate_node_transform(node, current_frame)
	#Node3DFrameInfo.recreate_frame(node, recorded_info[current_frame - spawn_frame])


const FLOAT_SIZE := 2

const TRANSFORM_SIZE := 12


func capture_node_transform(node: Node) -> void:
	var offset: int = recorded_transform_info.size()
	
	recorded_transform_info.resize(offset + FLOAT_SIZE * TRANSFORM_SIZE)
	
	var global_transform: Transform3D = node.global_transform
	
	recorded_transform_info.encode_half(offset, global_transform.basis.x.x)
	offset += FLOAT_SIZE
	recorded_transform_info.encode_half(offset, global_transform.basis.x.y)
	offset += FLOAT_SIZE
	recorded_transform_info.encode_half(offset, global_transform.basis.x.z)
	offset += FLOAT_SIZE
	recorded_transform_info.encode_half(offset, global_transform.basis.y.x)
	offset += FLOAT_SIZE
	recorded_transform_info.encode_half(offset, global_transform.basis.y.y)
	offset += FLOAT_SIZE
	recorded_transform_info.encode_half(offset, global_transform.basis.y.z)
	offset += FLOAT_SIZE
	recorded_transform_info.encode_half(offset, global_transform.basis.z.x)
	offset += FLOAT_SIZE
	recorded_transform_info.encode_half(offset, global_transform.basis.z.y)
	offset += FLOAT_SIZE
	recorded_transform_info.encode_half(offset, global_transform.basis.z.z)
	offset += FLOAT_SIZE
	recorded_transform_info.encode_half(offset, global_transform.origin.x)
	offset += FLOAT_SIZE
	recorded_transform_info.encode_half(offset, global_transform.origin.y)
	offset += FLOAT_SIZE
	recorded_transform_info.encode_half(offset, global_transform.origin.z)



func recreate_node_transform(node: Node, current_frame: int) -> void:
	var offset: int = (current_frame - spawn_frame) * FLOAT_SIZE * TRANSFORM_SIZE
	
	node.global_transform = Transform3D(
		Vector3(
			recorded_transform_info.decode_half(offset + 0 * FLOAT_SIZE),
			recorded_transform_info.decode_half(offset + 1 * FLOAT_SIZE),
			recorded_transform_info.decode_half(offset + 2 * FLOAT_SIZE),
		),
		Vector3(
			recorded_transform_info.decode_half(offset + 3 * FLOAT_SIZE),
			recorded_transform_info.decode_half(offset + 4 * FLOAT_SIZE),
			recorded_transform_info.decode_half(offset + 5 * FLOAT_SIZE),
		),
		Vector3(
			recorded_transform_info.decode_half(offset + 6 * FLOAT_SIZE),
			recorded_transform_info.decode_half(offset + 7 * FLOAT_SIZE),
			recorded_transform_info.decode_half(offset + 8 * FLOAT_SIZE),
		),
		Vector3(
			recorded_transform_info.decode_half(offset + 9 * FLOAT_SIZE),
			recorded_transform_info.decode_half(offset + 10 * FLOAT_SIZE),
			recorded_transform_info.decode_half(offset + 11 * FLOAT_SIZE),
		)
	)
