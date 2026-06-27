@tool
class_name SpinBlur
extends Node3D

const ENVELOPING_MESH_FRONT_SHADER: Shader = preload("res://addons/sphynx's_spin_blur_toolkit/spin_blur_mesh_front.gdshader")

const ENVELOPING_MESH_BACK_SHADER: Shader = preload("res://addons/sphynx's_spin_blur_toolkit/spin_blur_mesh_back.gdshader")

const DEBUG_SHADER: Shader = preload("res://addons/sphynx's_spin_blur_toolkit/debug_spin_mesh.gdshader")

const ENVELOPING_NODE_META_KEY: StringName = &"spin_blur_enveloping_node"


@export var target: Node3D:
	set = _set_target

@export var enabled := true:
	set = _set_enabled

## A render layer reserved for the spin blur to do its thing. Multiple spin
## blurs can use the same render layer, with a slight caveat that if their targets
## overlap it can results in some artifacts.
## The value range is 3 - 20. Setting it to 1 would clash with the default render
## layer, and setting it to 2 would break gizmos in the editor.
@export_range(3, 20, 1) var reserved_render_layer: int = 3:
	set = _set_layer

## When disabling/removing the spin blur, it will revent the render layers of
## [member target] to this value
@export_flags_3d_render var layers_to_revert = 1

## A rotation axis local to [member target] along which spin blur will occur
@export var target_rotation_axis: Vector3 = Vector3(1, 0, 0)

@export_subgroup("activation speed thresholds", "activation_speed_threshold")

## Above this rotation speed (in radians per frame), the spin blur will start
## fading in.
@export var activation_speed_threshold_lower: float = 0.0:
	set = _set_activation_speed_threshold_lower

## Above this rotation speed (in radians per frame), the spin blur will be fully
## faded in, and the target mesh will be turned invisible.
@export var activation_speed_threshold_upper: float = 0.0:
	set = _set_activation_speed_threshold_upper

var _activation_threshold_setter_gate := false

## Amount of motion blur samples. Higher values result in higher quality and smoothness
## at the cost of performance.
@export_range(1, 32, 1, "or_greater") var sample_count := 8

## Higher values mean grater blur angle for the same rotation speed. At 1.0
## the blur would span the rotation step fully, at 0.5, only half the rotation
## step would be blurred along, and so on. 
@export_range(0.0, 1.0, 0.001, "or_greater") var blur_intensity: float = 1.0

## The higher the value, the more pronounced the rolling shutter effect. Works independently
## from [member blur_intensity], i.e. you can have rolling shutter without blur if you want.
## Applied in terms of rotation_speed * screen_height_fraction_offset * rolling_shutter_amount.
@export var rolling_shutter_amount: float = 0.0

## A tool button to detect lighting-related nodes and ensure they are visible under
## [member reserved_render_layer] render layer.
@export_tool_button("Capture Lighting") var _capture_lighting = capture_lighting

## The enveloping mesh is what makes the spin blur possible. It is a mesh that tightly
## encapsulates the space the target mesh sweeps through as it rotates. You can generate
## it automatically after setting [member target_rotation_axis] by pressing [member generate_enveloping_mesh]
## tool button.
@export var enveloping_mesh: Mesh:
	set = _set_enveloping_mesh

@export_group("enveloping mesh generation")

## When generating the enveloping mesh, defines how many rings of vertices
## to use. Higher values mean higher details
@export var rings: int = 16

## How many radial segments to generate the mesh with. Higher value means
## more circular mesh.
@export var radial_segments: int = 32

## The mesh generation is not perfect, it's based on a polar vertex profile, which disregards faces
## and edges. If you have a very simple mesh with large faces that the rotation axis goes through,
## the generated mesh may end up with a hole in its center. If you have a mesh with an intentional
## hole in its center, set this variable to [code]false[/code]
@export var fill_center: bool = true

## The mesh generation captures all mesh instances that are children of the target node,
## and generates separate mesh surfaces for each by default. Setting this to [code]true[/code]
## will generate a single surface to envelop all meshes.
@export var unify_meshes: bool = true

## Add padding to the generated mesh in perpendicular to the rotation axis (make it wider)
@export var radial_padding: float = 0

## Add padding to the generated mesh along the rotation axis 
@export var depth_padding: float = 0

## When pressed, generates an enveloping mesh for the target mesh based on it and the
## axis set in [member target_rotation_axis].
@export_tool_button("generate enveloping mesh") var generate_enveloping_mesh = _generate_enveloping_mesh

@export_group("debug")

## Allows you to simulate the behavior of the blur in the editor at different rotation speeds.
## This would not actually rotate the mesh, just show you what the blur would look like if it did.
@export var override_rotation_speed := 0.0

## A color to display the enveloping mesh wireframe with.
@export var debug_color: Color = Color("ffffff0a")

## Whether to show the enveloping mesh in the editor.
@export var draw_debug := true

var _viewport: SubViewport:
	set = _set_viewport

var _camera: SpinBlurCamera:
	set = _set_camera

# Whether the spin blur is truly enabled. It is determined based
# on whether it is ready, whether it has a target, and whether [mermber enabled] is true
var _enabled: bool = false:
	set(value):
		if _enabled == value:
			return
		
		_enabled = value
		
		if _enabled:
			_enable()
			
		else:
			_disable()

var _layer_mask: int = 1 << (reserved_render_layer - 1)

var _enveloping_node: MeshInstance3D

var _past_global_transform: Transform3D

var _debug_material: ShaderMaterial

var _rotation_vector_cache: Vector3

var _rotation_speed_cache: float


func _enter_tree() -> void:
	SpinBlurHelpers.register_spin_blur(self)
	
	_update_enabled()


func _exit_tree() -> void:
	SpinBlurHelpers.unregister_spin_blur(self)
	
	_enabled = false


func _ready() -> void:
	for child in get_children():
		if child.has_meta(ENVELOPING_NODE_META_KEY):
			child.queue_free()
	
	_enveloping_node = MeshInstance3D.new()
	
	_enveloping_node.set_meta(ENVELOPING_NODE_META_KEY, true)
	
	var front_material := ShaderMaterial.new()
	
	front_material.shader = ENVELOPING_MESH_FRONT_SHADER
	
	front_material.render_priority = 1
	
	# This commented out code is there for archival purposes.
	# I created the back shader to support showing the blur
	# if you are enside the mesh, however it is not practical
	# given the much better enveloping mesh system.
	#var back_material := ShaderMaterial.new()
	#
	#back_material.shader = ENVELOPING_MESH_BACK_SHADER
	#
	#back_material.render_priority = 2
	#
	#front_material.next_pass = back_material
	
	if Engine.is_editor_hint():
		_debug_material = ShaderMaterial.new()
		_debug_material.shader = DEBUG_SHADER
		_debug_material.render_priority = 3
		
		#back_material.next_pass = _debug_material
		front_material.next_pass = _debug_material
	
	_enveloping_node.material_override = front_material
	
	add_child(_enveloping_node)
	
	# So that the viewport's view does not lag a frame behind the reference camera
	process_priority = 1
	
	_update_viewport_texture()
	_update_depth_texture()
	_update_enveloping_mesh()
	_update_enabled()


func _process(delta: float) -> void:
	if !_enabled:
		return
	
	if target_rotation_axis.is_zero_approx():
		return
	
	_update_enveloping_node()


## Detects lighting-related nodes and ensure they are visible under
## [member reserved_render_layer] render layer.
func capture_lighting() -> void:
	var lights_to_copy: Array[Node]
	
	_scan_for_lighting(get_viewport(), get_viewport(), lights_to_copy)
	
	for light: Node in lights_to_copy:
		light.layers |= _layer_mask


func _enable() -> void:
	_target_set_layers_recursive(target, layers_to_revert | _layer_mask)


func _disable() -> void:
	_target_set_layers_recursive(target, layers_to_revert)
	visible = false


func _scan_for_lighting(node: Node, parent_viewport: Viewport, result: Array[Node]) -> void:
	if node is Viewport and node != parent_viewport:
		return
	
	if node is Light3D:
		result.append(node)
	
	for child in node.get_children():
		_scan_for_lighting(child, parent_viewport, result)


func _set_shader_parameter_recursive(
	material: ShaderMaterial, 
	parameter: String, 
	value: Variant
) -> void:
	if material.next_pass and material.next_pass is ShaderMaterial:
		_set_shader_parameter_recursive(material.next_pass, parameter, value)
	
	material.set_shader_parameter(parameter, value)


func _generate_enveloping_mesh() -> void:
	if !target:
		push_error("invalid target")
		return
	
	if target_rotation_axis.is_zero_approx():
		push_error("invalid rotation axis")
		return
	
	enveloping_mesh = SpinMesh.generate(
		_collect_target_meshes_recursive(target), 
		target_rotation_axis, 
		rings, 
		radial_segments, 
		fill_center,
		unify_meshes,
		radial_padding, 
		depth_padding,
	)


func _collect_target_meshes_recursive(
	root: Node3D,
	node: Node = root, 
	ret: Dictionary[MeshInstance3D, Transform3D] = {}
) -> Dictionary[MeshInstance3D, Transform3D]:
	if node is MeshInstance3D and node.mesh and \
	!(node is GeometryInstance3D and node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY):
		ret[node as MeshInstance3D] = root.global_transform.affine_inverse() * node.global_transform
	
	for child in node.get_children():
		if child == self:
			continue
		
		_collect_target_meshes_recursive(root, child, ret)
	
	return ret


func _update_enabled() -> void:
	_enabled = is_node_ready() and enabled and target


func _update_enveloping_node() -> void:
	if Engine.is_editor_hint():
		_debug_material.set_shader_parameter(
			"color", 
			debug_color
		)
		
		_debug_material.set_shader_parameter(
			"enabled", 
			1 if draw_debug else 0
		)
	
	_set_shader_parameter_recursive(
		_enveloping_node.material_override,
		"rolling_shutter_amount", 
		rolling_shutter_amount
	)
	
	_set_shader_parameter_recursive(
		_enveloping_node.material_override,
		"sample_count", 
		sample_count
	)
	
	var target_transform : Transform3D = target.global_transform
	
	_rotation_vector_cache = target_transform.orthonormalized().basis * target_rotation_axis
	
	_set_shader_parameter_recursive(
		_enveloping_node.material_override,
		"local_rotation_axis",
		 target_rotation_axis
	)
	
	var difference_quat: Quaternion = Quaternion(target_transform.basis.get_rotation_quaternion() \
	* _past_global_transform.basis.get_rotation_quaternion().inverse())
	
	var centered_angle: float = difference_quat.get_angle() - PI
	
	var angle: float = (PI - abs(centered_angle)) * abs(_rotation_vector_cache.dot(difference_quat.get_axis()))
	
	if !Engine.is_editor_hint() and target.has_method("_get_rotation_speed"):
		angle = target._get_rotation_speed()
	
	_rotation_speed_cache = angle \
	if override_rotation_speed == 0.0 or !Engine.is_editor_hint() \
	else override_rotation_speed
	
	_set_shader_parameter_recursive(
		_enveloping_node.material_override,
		"rotation_speed", 
		_rotation_speed_cache
	)
	
	_set_shader_parameter_recursive(
		_enveloping_node.material_override,
		"blur_intensity", 
		blur_intensity,
	)
	
	if abs(_rotation_speed_cache) > activation_speed_threshold_upper:
		_target_set_layers_recursive(target, _layer_mask)
		
	else:
		_target_set_layers_recursive(target, layers_to_revert | _layer_mask)
	
	if abs(_rotation_speed_cache) > activation_speed_threshold_lower or (draw_debug and Engine.is_editor_hint()):
		visible = true
		
	else:
		visible = false
	
	var fade_in_coef: float = clamp(
		(abs(_rotation_speed_cache) - activation_speed_threshold_lower) / \
		max(0.0001, activation_speed_threshold_upper - activation_speed_threshold_lower), 
		0, 
		1
	)
	
	_set_shader_parameter_recursive(
		_enveloping_node.material_override,
		"fade_in", 
		fade_in_coef
	)
	
	_past_global_transform = target_transform
	
	_enveloping_node.global_position = target_transform.origin
	
	var alignment_quaternion : Quaternion = \
	Quaternion(_enveloping_node.global_basis.orthonormalized() \
	* target_rotation_axis, _rotation_vector_cache)
	
	_enveloping_node.global_basis = \
	Basis(alignment_quaternion) * _enveloping_node.global_basis;
	
	_enveloping_node.global_basis.x = \
	_enveloping_node.global_basis.x.normalized() * target_transform.basis.x.length()
	
	_enveloping_node.global_basis.y = \
	_enveloping_node.global_basis.y.normalized() * target_transform.basis.y.length()
	
	_enveloping_node.global_basis.z = \
	_enveloping_node.global_basis.z.normalized() * target_transform.basis.z.length()


func _target_set_layers_recursive(root: Node, layers: int) -> void:
	if "layers" in root and \
	!(root is GeometryInstance3D and root.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY):
		root.layers = layers
	
	for child in root.get_children():
		if child == self:
			continue
		
		_target_set_layers_recursive(child, layers)


func _update_viewport_texture() -> void:
	if !is_node_ready():
		return
	
	_set_shader_parameter_recursive(
		_enveloping_node.material_override,
		"screen_texture",
		_viewport.get_texture() if _viewport else null
	)


func _update_depth_texture() -> void:
	if !is_node_ready():
		return
	
	var texture: Texture2D = null
	
	if _camera:
		texture = _camera.compositor.compositor_effects[0].texture_2d_rd
	
	_set_shader_parameter_recursive(
		_enveloping_node.material_override,
		"depth_texture", 
		texture
	)


func _update_enveloping_mesh() -> void:
	if _enveloping_node:
		_enveloping_node.mesh = enveloping_mesh


func _set_enabled(value: bool) -> void:
	enabled = value
	
	_update_enabled()


func _set_layer(value: int) -> void:
	if reserved_render_layer == value:
		return
	
	reserved_render_layer = value
	
	_layer_mask = 1 << (reserved_render_layer - 1)
	
	if is_inside_tree():
		SpinBlurHelpers.sync_spin_blur_layer(self)


func _set_target(value: Node3D) -> void:
	target = value
	
	_update_enabled()
	
	update_configuration_warnings()


func _set_enveloping_mesh(value: Mesh) -> void:
	enveloping_mesh = value
	
	_update_enveloping_mesh()
	
	update_configuration_warnings()


func _set_activation_speed_threshold_lower(value: float) -> void:
	value = max(0, value)
	activation_speed_threshold_lower = value
	
	if _activation_threshold_setter_gate:
		return
	
	_activation_threshold_setter_gate = true
	
	activation_speed_threshold_upper = \
	max(activation_speed_threshold_upper, activation_speed_threshold_lower)
	
	_activation_threshold_setter_gate = false


func _set_activation_speed_threshold_upper(value: float) -> void:
	value = max(0, value)
	activation_speed_threshold_upper = value
	
	if _activation_threshold_setter_gate:
		return
	
	_activation_threshold_setter_gate = true
	
	activation_speed_threshold_lower = \
	min(activation_speed_threshold_upper, activation_speed_threshold_lower)
	
	_activation_threshold_setter_gate = false


func _set_viewport(value: SubViewport) -> void:
	_viewport = value
	
	_update_viewport_texture()


func _set_camera(value: SpinBlurCamera) -> void:
	if _camera:
		var old_signal: Signal = _camera.compositor.compositor_effects[0].texture_generated
		
		if old_signal.is_connected(_update_depth_texture):
			old_signal.disconnect(_update_depth_texture)
	
	_camera = value
	
	if _camera:
		var new_signal: Signal = _camera.compositor.compositor_effects[0].texture_generated
		
		if !new_signal.is_connected(_update_depth_texture):
			new_signal.connect(_update_depth_texture.unbind(1))
	
	_update_depth_texture()
