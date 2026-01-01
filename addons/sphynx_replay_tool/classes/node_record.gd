class_name NodeRecord
extends Resource

# The initial state of a node, used to recreate it
@export_storage var node_inisial_state: NodeInitialState

@export_storage var spawn_frame: int = 0

## Records of all important information in a node's life
## ordered by the frame in which they were captured
@export_storage var recorded_info: Array[NodeFrameInfo]


@abstract 
class NodeInitialState:
	extends Resource
	
	@export_storage var state: Dictionary[String, Variant]
	
	
	static func capture_node_initial_state(node: Node) -> NodeInitialState:
		if node is MeshInstance3D:
			return MeshInstance3DInitialState.new(node)
		else:
			return null
	
	
	func _init(node: MeshInstance3D) -> void:
		_capture_node_initial_state(node)
	
	
	@abstract func recreate_node() -> Node
	
	@abstract func _capture_node_initial_state(node: Node) -> void


class MeshInstance3DInitialState:
	extends NodeInitialState
	
	
	func _capture_node_initial_state(node: Node) -> void:
		for property in ReplayUtils.get_native_class_property_list("MeshInstance3D"):
			var value: Variant = node.get(property)
			
			if value is Resource:
				value = value.duplicate(true)
				
			elif value is Node:
				continue
			
			state[property] = value
	
	
	func recreate_node() -> Node:
		var new_node := MeshInstance3D.new()
		
		for property: String in state.keys():
			var value: Variant = state[property]
			
			if value is Resource:
				new_node.set(property, value.duplicate(true))
				
			else:
				new_node.set(property, value)
		
		return new_node


class NodeFrameInfo:
	extends Resource
	
	@export_storage var frame: int = 0
	
	@export_storage var global_transform: Transform3D
	
	
	static func should_capture(node: Node, past_frame_info: NodeFrameInfo) -> bool:
		return node.global_transform != past_frame_info.global_transform
	
	
	static func capture_node_frame_info(node: Node, current_frame: int) -> NodeFrameInfo:
		return NodeFrameInfo.new(node, current_frame)
	
	
	func _init(node: Node, current_frame: int) -> void:
		_capture_frame_info(node)
		frame = current_frame
	
	
	func _capture_frame_info(node: Node) -> void:
		global_transform = node.global_transform
