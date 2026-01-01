class_name MeshInstance3DInitialState
extends NodeInitialState

const PROPERTY_LIST: Array[String] = [
	"mesh", 
	"Skeleton", 
	"skin", 
	"skeleton",
	"Geometry", 
	"material_override", 
	"material_overlay", 
	"transparency", 
	"cast_shadow", 
	"extra_cull_margin", 
	"custom_aabb", 
	"lod_bias", 
	"ignore_occlusion_culling", 
	"Global Illumination", 
	"gi_mode", 
	"gi_lightmap_texel_scale", 
	"gi_lightmap_scale", 
	"Visibility Range", 
	"visibility_range_begin", 
	"visibility_range_begin_margin", 
	"visibility_range_end", 
	"visibility_range_end_margin", 
	"visibility_range_fade_mode", 
	"layers", 
	"Sorting", 
	"sorting_offset", 
	"sorting_use_aabb_center", 
	"transform",
	"top_level",
	"Visibility", 
	"visible", 
	"visibility_parent",
]

static func recreate_node(state: Variant) -> Node:
	var new_node := MeshInstance3D.new()
	
	for i in PROPERTY_LIST.size():
		var value: Variant = state[i]
		
		if value is Resource:
			new_node.set(PROPERTY_LIST[i], value.duplicate(true))
			
		else:
			new_node.set(PROPERTY_LIST[i], value)
	
	for i in range(PROPERTY_LIST.size(), state.size()):
		new_node.set("surface_material_override/" + str(i - PROPERTY_LIST.size()), state[i])
	
	return new_node


static func capture_node_initial_state(node: Node) -> Variant:
	var state: Array[Variant]
	
	for property in PROPERTY_LIST:
		if property.begins_with("global_"):
			continue
		
		var value: Variant = node.get(property)
		
		if value is Resource:
			value = value.duplicate(true)
			
		elif value is Node:
			continue
		
		state.append(value)
	
	for i in node.get_surface_override_material_count():
		state.append(node.get_surface_override_material(i))
	
	return state
