class_name MeshInstance3DInitialState
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
		if property.begins_with("global_"):
			continue
		
		var value: Variant = node.get(property)
		
		if value is Resource:
			value = value.duplicate(true)
			
		elif value is Node:
			continue
		
		state[property] = value
	
	for i in node.get_surface_override_material_count():
		state["surface_material_override/" + str(i)] = node.get_surface_override_material(i) 
