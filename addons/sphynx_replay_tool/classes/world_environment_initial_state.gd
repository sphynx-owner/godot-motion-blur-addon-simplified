class_name WorldEnvironmentInitialState
extends NodeInitialState

static func recreate_node(state: Variant) -> Node:
	return state.instantiate()


static func capture_node_initial_state(node: Node) -> Variant:
	var packed_scene := PackedScene.new()
	packed_scene.pack(node)
	return packed_scene
