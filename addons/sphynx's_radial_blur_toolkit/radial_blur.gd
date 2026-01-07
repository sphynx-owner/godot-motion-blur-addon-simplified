@tool
class_name RadialBlur
extends Node3D

const ENVELOPING_MESH_FRONT_SHADER: Shader = preload("res://addons/sphynx's_radial_blur_toolkit/radial_blur_mesh_front.gdshader")

const ENVELOPING_MESH_BACK_SHADER: Shader = preload("res://addons/sphynx's_radial_blur_toolkit/radial_blur_mesh_back.gdshader")

@export var enabled := true:
	set(value):
		enabled = value
		
		if enabled:
			if target:
				_layer_mask_cache = target.layers
			
		else:
			visible = false
			
			if target:
				target.layers = _layer_mask_cache

@export var target: MeshInstance3D:
	set(value):
		if target:
			target.layers = _layer_mask_cache
		
		target = value
		
		if target:
			_layer_mask_cache = target.layers
		
		update_configuration_warnings()

@export var enveloping_mesh: Mesh:
	set(value):
		enveloping_mesh = value
		
		update_configuration_warnings()

@export var target_rotation_axis: Vector3

@export var activation_speed_lower_threshold: float = 0.1:
	set(value):
		value = max(0, value)
		activation_speed_lower_threshold = value
		
		if _activation_threshold_setter_gate:
			return
		
		_activation_threshold_setter_gate = true
		
		activation_speed_upper_threshold = \
		max(activation_speed_lower_threshold, activation_speed_lower_threshold)
		
		_activation_threshold_setter_gate = false

@export var activation_speed_upper_threshold: float = 0.2:
	set(value):
		value = max(0, value)
		
		if _activation_threshold_setter_gate:
			return
		
		_activation_threshold_setter_gate = true
		
		activation_speed_upper_threshold = value
		activation_speed_lower_threshold = \
		min(activation_speed_lower_threshold, activation_speed_lower_threshold)
		
		_activation_threshold_setter_gate = false

@export var sample_count := 8

@export_group("debug")

@export var override_rotation_speed := 0.0

@export var debug_color: Color = Color.TRANSPARENT

@export var draw_debug := false

var _activation_threshold_setter_gate := false

var _layer_mask_cache: int = false

var _viewport: SubViewport

var _camera: Camera3D

var _clone: MeshInstance3D

var _enveloping_node: MeshInstance3D

var _past_global_transform: Transform3D


func _exit_tree() -> void:
	if target:
		target.layers = _layer_mask_cache


func _ready() -> void:
	_viewport = SubViewport.new()
	
	_viewport.own_world_3d = true
	
	_viewport.transparent_bg = true
	
	_viewport.debug_draw = Viewport.DEBUG_DRAW_UNSHADED
	
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	_viewport.use_hdr_2d = true
	
	_viewport.anisotropic_filtering_level = Viewport.ANISOTROPY_DISABLED
	
	add_child(_viewport)
	
	_camera = Camera3D.new()
	
	_camera.compositor = Compositor.new()
	
	_camera.compositor.compositor_effects = [DepthCompositorEffect.new()]
	
	_camera.compositor.compositor_effects[0].texture_generated.connect(
		_on_depth_texture_generated
	)
	
	_viewport.add_child(_camera)
	
	_clone = MeshInstance3D.new()
	
	_viewport.add_child(_clone)
	
	_enveloping_node = MeshInstance3D.new()
	
	var front_material := ShaderMaterial.new()
	
	front_material.shader = ENVELOPING_MESH_FRONT_SHADER
	
	var back_material := ShaderMaterial.new()
	
	back_material.shader = ENVELOPING_MESH_BACK_SHADER
	
	back_material.render_priority = 1
	
	front_material.next_pass = back_material
	
	_enveloping_node.material_override = front_material
	
	add_child(_enveloping_node)
	
	# So that the viewport's view does not lag a frame behind the reference camera
	process_priority = 1


func _process(delta: float) -> void:
	if !enabled:
		return
	
	_update_viewport()
	_update_camera()
	_update_clone()
	_update_enveloping_node()


func _on_depth_texture_generated(depth_texture: Texture2DRD) -> void:
	set_shader_parameter_recursive(
		_enveloping_node.material_override,
		"depth_texture", 
		depth_texture
	)
	set_shader_parameter_recursive(
		_enveloping_node.material_override,
		"screen_texture", 
		_viewport.get_texture()
	)


func _update_viewport() -> void:
	var reference_viewport: Viewport
	
	if Engine.is_editor_hint():
		reference_viewport = EditorInterface.get_editor_viewport_3d()
	else:
		reference_viewport = get_viewport()
	
	if "size" in reference_viewport:
		_viewport.size = reference_viewport.size


func _update_camera() -> void:
	var reference_camera: Camera3D
	
	if Engine.is_editor_hint():
		reference_camera = EditorInterface.get_editor_viewport_3d().get_camera_3d()
	else:
		reference_camera = get_viewport().get_camera_3d()
	
	_camera.global_transform = reference_camera.global_transform
	_camera.fov = reference_camera.fov
	_camera.projection = reference_camera.projection


func _update_clone() -> void:
	if !target:
		return
	
	_clone.global_transform = target.global_transform
	
	if !target.mesh:
		_clone.mesh = null
		return
	
	_clone.mesh = target.mesh
	
	for i: int in range(target.get_surface_override_material_count()):
		_clone.set_surface_override_material(
			i, 
			target.get_surface_override_material(i)
		)
	
	_clone.material_override = target.material_override
	
	_clone.material_overlay = target.material_overlay


func _update_enveloping_node() -> void:
	if !enveloping_mesh:
		return
	
	_enveloping_node.mesh = enveloping_mesh
	
	set_shader_parameter_recursive(
		_enveloping_node.material_override,
		"debug_color", 
		debug_color
	)
	
	set_shader_parameter_recursive(
		_enveloping_node.material_override,
		"use_debug", 
		1 if draw_debug else 0
	)
	
	set_shader_parameter_recursive(
		_enveloping_node.material_override,
		"sample_count", 
		sample_count
	)
	
	var target_transform : Transform3D = target.global_transform
	
	var target_rotation_vector : Vector3 = \
	target_transform.orthonormalized().basis * target_rotation_axis
	
	set_shader_parameter_recursive(
		_enveloping_node.material_override,
		"local_rotation_axis",
		 target_rotation_axis
	)
	
	var difference_quat : Quaternion = \
	Quaternion(target_transform.basis.get_rotation_quaternion() \
	* _past_global_transform.basis.get_rotation_quaternion().inverse())
	
	var centered_angle : float = difference_quat.get_angle() - PI
	
	var angle = (PI - abs(centered_angle)) \
	* abs(target_rotation_vector.dot(difference_quat.get_axis()))
	
	var rotation_speed: float = clamp(angle, -TAU, TAU) \
	if override_rotation_speed == 0.0 or !Engine.is_editor_hint() \
	else override_rotation_speed
	
	set_shader_parameter_recursive(
		_enveloping_node.material_override,
		"rotation_speed", 
		rotation_speed
	)
	
	if abs(rotation_speed) > activation_speed_upper_threshold:
		target.layers = 0
	else:
		target.layers = _layer_mask_cache
	
	if abs(rotation_speed) > activation_speed_lower_threshold:
		visible = true
	else:
		visible = false
	
	var fade_in_coef: float = clamp(
		(rotation_speed - activation_speed_lower_threshold) \
		/ (activation_speed_upper_threshold - activation_speed_lower_threshold), 
		0, 
		1
	)
	
	set_shader_parameter_recursive(
		_enveloping_node.material_override,
		"fade_in", 
		fade_in_coef
	)
	
	_past_global_transform = target_transform
	
	_enveloping_node.global_position = target_transform.origin
	
	var alignment_quaternion : Quaternion = \
	Quaternion(_enveloping_node.global_basis.orthonormalized() \
	* target_rotation_axis, target_rotation_vector)
	
	_enveloping_node.global_basis = \
	Basis(alignment_quaternion) * _enveloping_node.global_basis;
	
	_enveloping_node.global_basis.x = \
	_enveloping_node.global_basis.x.normalized() * target_transform.basis.x.length()
	
	_enveloping_node.global_basis.y = \
	_enveloping_node.global_basis.y.normalized() * target_transform.basis.y.length()
	
	_enveloping_node.global_basis.z = \
	_enveloping_node.global_basis.z.normalized() * target_transform.basis.z.length()


func set_shader_parameter_recursive(
	material: ShaderMaterial, 
	parameter: String, 
	value: Variant
) -> void:
	material.set_shader_parameter(parameter, value)
	
	if material.next_pass and material.next_pass is ShaderMaterial:
		set_shader_parameter_recursive(material.next_pass, parameter, value)
