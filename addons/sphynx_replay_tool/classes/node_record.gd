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
	if current_frame <= recorded_info.back().frame:
		var err_string: String = "trying to record to a past or already existing frame number, not allowed"
		assert(false, err_string)
		push_error(err_string)
	
	if node is Node3D:
		recorded_info.append(Node3DFrameInfo.new(node, current_frame))


func close_node_record(current_frame: int) -> void:
	despawn_frame = current_frame


@abstract 
class NodeInitialState:
	extends Resource
	
	@export_storage var state: Dictionary[String, Variant]
	
	
	func _init(node: MeshInstance3D) -> void:
		_capture_node_initial_state(node)
	
	
	@abstract func recreate_node() -> Node
	
	@abstract func _capture_node_initial_state(node: Node) -> void


class MeshInstance3DInitialState:
	extends NodeInitialState
	
	
	func recreate_node() -> Node:
		var new_node := MeshInstance3D.new()
		
		for property: String in state.keys():
			var value: Variant = state[property]
			
			if value is Resource:
				new_node.set(property, value.duplicate(true))
				
			else:
				new_node.set(property, value)
		
		return new_node
	
	
	func _capture_node_initial_state(node: Node) -> void:
		for property in ReplayUtils.get_native_class_property_list("MeshInstance3D"):
			var value: Variant = node.get(property)
			
			if value is Resource:
				value = value.duplicate(true)
				
			elif value is Node:
				continue
			
			state[property] = value


@abstract
class NodeFrameInfo:
	extends Resource
	
	@export_storage var frame: int = 0
	
	@export_storage var state: Dictionary[String, Variant]
	
	
	func _init(node: Node, current_frame: int) -> void:
		_capture_node_frame_info(node)
		frame = current_frame
	
	
	static func should_capture(node: Node, past_frame_info: NodeFrameInfo) -> bool:
		return false
	
	
	@abstract func recreate_frame(node: Node) -> void
	
	@abstract func _capture_node_frame_info(node: Node) -> void


class Node3DFrameInfo:
	extends NodeFrameInfo
	
	
	static func should_capture(node: Node, past_frame_info: NodeFrameInfo) -> bool:
		return node.global_transform != past_frame_info.state.global_transform
	
	
	func recreate_frame(node: Node) -> void:
		node.global_transform = state.global_transform
	
	
	func _capture_node_frame_info(node: Node) -> void:
		state.global_transform = node.global_transform
