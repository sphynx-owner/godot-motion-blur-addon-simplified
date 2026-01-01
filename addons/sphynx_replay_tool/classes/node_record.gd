class_name NodeRecord
extends Resource

# The initial state of a node, used to recreate it
@export_storage var node_initial_state: NodeInitialState

@export_storage var spawn_frame: int = 0
@export_storage var despawn_frame: int = 0

## Records of all important information in a node's life
## ordered by the frame in which they were captured
@export_storage var recorded_info: Array[NodeFrameInfo]


static func can_record_node(node: Node) -> bool:
	return node is MeshInstance3D


func capture_node_initial_state(node: Node, current_frame: int) -> void:
	if node is MeshInstance3D:
		node_initial_state = MeshInstance3DInitialState.new(node)
	
	spawn_frame = current_frame


func capture_node_frame_info(node: Node, current_frame: int) -> void:
	if !recorded_info.is_empty() and current_frame <= recorded_info.back().frame:
		var err_string: String = "trying to record to a past or already existing frame number, not allowed"
		assert(false, err_string)
		push_error(err_string)
	
	if node is Node3D:
		recorded_info.append(Node3DFrameInfo.new(node, current_frame))


func close_node_record(current_frame: int) -> void:
	despawn_frame = current_frame


func recreate_node() -> Node:
	return node_initial_state.recreate_node()


func recreate_frame(node: Node, current_frame: int) -> void:
	recorded_info[current_frame - spawn_frame].recreate_frame(node)
