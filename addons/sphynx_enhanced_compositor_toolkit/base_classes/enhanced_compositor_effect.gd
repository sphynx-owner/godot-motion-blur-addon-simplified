@tool
extends CompositorEffect
#class_name EnhancedCompositorEffect
## This script contains and handles a lot of the boilerplate required for setting up a functioning compositor effcet
## It also establishes a debugging pattern that compute shaders can hook onto with pre processors
## Using this while not the most efficient is great for setting quick effects to experiment with.


# These have to match with the category and property prefix that 
# the shader material gives its uniform properties under the Shader Parameter property
# category
const shader_stages_category: String = "Shader Stages"
const shader_stages_category_prefix: String = "shader_stages/"

## Enabling this would include the DEBUG pre-processor in 
## the compute shader before compiling and creating the pipeline,
## As well as adding debug image uniforms and binding them automatically.
## This makes it easier to add behavior that is specific for debugging 
## like printing images to a debug screen that can be toggled with Z
## and cycled through with C, as well as freeze the screen with X.
## requires the DebugCompositorEffect at the end of the compositor_effects array to be usable
@export var debug : bool = false:
	set(value):
		if(debug == value):
			return
		
		debug = value
		_generate_all_shader_stages.call_deferred()

var rd: RenderingDevice

var linear_sampler: RID

var nearest_sampler : RID

var context: StringName = "PostProcess"

var _all_shader_stages : Dictionary

var debug_1 : String = "debug_1"
var debug_2 : String = "debug_2"
var debug_3 : String = "debug_3"
var debug_4 : String = "debug_4"
var debug_5 : String = "debug_5"
var debug_6 : String = "debug_6"
var debug_7 : String = "debug_7"
var debug_8 : String = "debug_8"

var all_debug_images : Array[RID]

var _set_gate: bool = true

#region static functions

static func static_free_shader_stage(in_rd: RenderingDevice, shader_stage_resource: ShaderStageResource):
	if in_rd.compute_pipeline_is_valid(shader_stage_resource.pipeline):
		in_rd.free_rid(shader_stage_resource.pipeline)
		shader_stage_resource.pipeline = RID()
	if shader_stage_resource.shader.is_valid():
		in_rd.free_rid(shader_stage_resource.shader)
		shader_stage_resource.shader = RID()

#endregion

#region override functions

func _init():
	RenderingServer.call_on_render_thread(_initialize_compute)


func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if !rd:
			return
		if linear_sampler.is_valid():
			rd.free_rid(linear_sampler)
		if nearest_sampler.is_valid():
			rd.free_rid(nearest_sampler)
		for shader_stage in _all_shader_stages:
			static_free_shader_stage(rd, shader_stage)


func _get_property_list() -> Array[Dictionary]:
	var property_list: Array[Dictionary] = _get_shader_stage_properties()
	property_list.push_front(
		{
			name = shader_stages_category,
			type = TYPE_NIL,
			hint_string = shader_stages_category_prefix,
			usage = PROPERTY_USAGE_GROUP
		}
	)
	return property_list


func _set(property: StringName, value: Variant) -> bool:
	if property.begins_with(shader_stages_category_prefix):
		var trimmed_property_name: String = property.trim_prefix(shader_stages_category_prefix)
		var current_shader_stage: ShaderStageResource = get(trimmed_property_name)
		
		free_shader_stage(current_shader_stage)
		
		if current_shader_stage and current_shader_stage.changed.is_connected(_generate_shader_stage):
			current_shader_stage.changed.disconnect(_generate_shader_stage)
		
		set(trimmed_property_name, value)
		
		current_shader_stage = value
		
		_generate_shader_stage(weakref(current_shader_stage))
		
		if current_shader_stage and !current_shader_stage.changed.is_connected(_generate_shader_stage):
			current_shader_stage.changed.connect(_generate_shader_stage.bind(weakref(current_shader_stage)))
		
		return true
	
	return false


func _get(property: StringName) -> Variant:
	if property.begins_with(shader_stages_category_prefix):
		return get(property.trim_prefix(shader_stages_category_prefix))
	
	return null


func _render_callback(p_effect_callback_type, p_render_data):
	if !rd:
		return
	
	var render_scene_buffers: RenderSceneBuffersRD = p_render_data.get_render_scene_buffers()
	var render_scene_data: RenderSceneDataRD = p_render_data.get_render_scene_data()
	if !render_scene_buffers or !render_scene_data:
		return
	
	var render_size: Vector2i = render_scene_buffers.get_internal_size()
	
	if render_size.x == 0 or render_size.y == 0:
		return
	
	if debug:
		ensure_texture(debug_1, render_scene_buffers)
		ensure_texture(debug_2, render_scene_buffers)
		ensure_texture(debug_3, render_scene_buffers)
		ensure_texture(debug_4, render_scene_buffers)
		ensure_texture(debug_5, render_scene_buffers)
		ensure_texture(debug_6, render_scene_buffers)
		ensure_texture(debug_7, render_scene_buffers)
		ensure_texture(debug_8, render_scene_buffers)
		
		var view_count = render_scene_buffers.get_view_count()
		
		for view in range(view_count):
			all_debug_images.append(render_scene_buffers.get_texture_slice(context, debug_1, view, 0, 1, 1))
			all_debug_images.append(render_scene_buffers.get_texture_slice(context, debug_2, view, 0, 1, 1))
			all_debug_images.append(render_scene_buffers.get_texture_slice(context, debug_3, view, 0, 1, 1))
			all_debug_images.append(render_scene_buffers.get_texture_slice(context, debug_4, view, 0, 1, 1))
			all_debug_images.append(render_scene_buffers.get_texture_slice(context, debug_5, view, 0, 1, 1))
			all_debug_images.append(render_scene_buffers.get_texture_slice(context, debug_6, view, 0, 1, 1))
			all_debug_images.append(render_scene_buffers.get_texture_slice(context, debug_7, view, 0, 1, 1))
			all_debug_images.append(render_scene_buffers.get_texture_slice(context, debug_8, view, 0, 1, 1))
	
	_render_callback_2(render_size, render_scene_buffers, render_scene_data)
	
	all_debug_images.clear()

#endregion

#region custom override function

func _render_callback_2(render_size : Vector2i, render_scene_buffers : RenderSceneBuffersRD, render_scene_data : RenderSceneDataRD):
	pass

#endregion

#region public functions

func setup_shader_stage(shader_stage : ShaderStageResource):
	_generate_shader_stage(weakref(shader_stage))


func free_shader_stage(shader_stage : ShaderStageResource):
	if !rd:
		return
	
	static_free_shader_stage(rd, shader_stage)


func ensure_texture(texture_name : StringName, render_scene_buffers : RenderSceneBuffersRD, texture_format : RenderingDevice.DataFormat = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, render_size_multiplier : Vector2 = Vector2(1, 1)):
	var render_size : Vector2i = Vector2(render_scene_buffers.get_internal_size()) * render_size_multiplier
	
	if render_scene_buffers.has_texture(context, texture_name):
		var tf: RDTextureFormat = render_scene_buffers.get_texture_format(context, texture_name)
		if tf.width != render_size.x or tf.height != render_size.y:
			render_scene_buffers.clear_context(context)

	if !render_scene_buffers.has_texture(context, texture_name):
		var usage_bits: int = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		render_scene_buffers.create_texture(context, texture_name, texture_format, usage_bits, RenderingDevice.TEXTURE_SAMPLES_1, render_size, 1, 1, true)


func get_image_uniform(image: RID, binding: int) -> RDUniform:
	var uniform: RDUniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = binding
	uniform.add_id(image)
	return uniform


func get_sampler_uniform(image: RID, binding: int, linear : bool = true) -> RDUniform:
	var uniform: RDUniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uniform.binding = binding
	uniform.add_id(linear_sampler if linear else nearest_sampler)
	uniform.add_id(image)
	return uniform



func dispatch_stage(stage : ShaderStageResource, uniforms : Array[RDUniform], push_constants : PackedByteArray, dispatch_size : Vector3i, label : String = "DefaultLabel", view : int = 0, color : Color = Color(1, 1, 1, 1)):
	rd.draw_command_begin_label(label + " " + str(view), color)
	
	var debug_uniforms : Array[RDUniform]
	var debug_uniform_set : RID
	
	if debug:
		for i in 8:
			var debug_image_index = i + view * 8;
			debug_uniforms.append(get_image_uniform(all_debug_images[debug_image_index], 10 + i))
	
	var tex_uniform_set = UniformSetCacheRD.get_cache(stage.shader, 0, uniforms)
	
	if debug:
		debug_uniform_set = UniformSetCacheRD.get_cache(stage.shader, 1, debug_uniforms)
	
	var compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, stage.pipeline)
	rd.compute_list_bind_uniform_set(compute_list, tex_uniform_set, 0)
	
	if debug:
		rd.compute_list_bind_uniform_set(compute_list, debug_uniform_set, 1)
	
	if !push_constants.is_empty():
		rd.compute_list_set_push_constant(compute_list, push_constants, push_constants.size())
		
	rd.compute_list_dispatch(compute_list, dispatch_size.x, dispatch_size.y, dispatch_size.z)
	
	rd.compute_list_end()
	
	rd.draw_command_end_label()

#endregion

#region private functions

func _initialize_compute():
	rd = RenderingServer.get_rendering_device()
	
	if !rd:
		return
	
	var sampler_state := RDSamplerState.new()
	
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler_state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	
	linear_sampler = rd.sampler_create(sampler_state)
	
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	sampler_state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler_state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	
	nearest_sampler = rd.sampler_create(sampler_state)
	
	_update_all_shader_stages()
	_generate_all_shader_stages()


func _get_shader_stage_properties() -> Array[Dictionary]:
	var new_property_list: Array[Dictionary]
	for property: Dictionary in (get_script() as GDScript).get_script_property_list():
		if property.class_name == &"ShaderStageResource":
			new_property_list.append(
				{
					name = shader_stages_category_prefix + property.name,
					type = TYPE_OBJECT,
					hint =  PROPERTY_HINT_RESOURCE_TYPE,
					hint_string = "ShaderStageResource",
				}
			)
	
	return new_property_list


func _update_all_shader_stages():
	_all_shader_stages.clear()
	var all_shader_stage_properties: Array[Dictionary] = _get_shader_stage_properties()
	for shader_stage_property: Dictionary in all_shader_stage_properties:
		var shader_stage: ShaderStageResource = get(shader_stage_property.name)
		shader_stage.changed.connect(_generate_shader_stage.bind(weakref(shader_stage)))
		_all_shader_stages[shader_stage] = 0


func _generate_all_shader_stages():
	for shader_stage: ShaderStageResource in _all_shader_stages.keys():
		_generate_shader_stage(weakref(shader_stage))


func _generate_shader_stage(shader_stage_weak_ref : WeakRef):
	var shader_stage: ShaderStageResource = shader_stage_weak_ref.get_ref()
	free_shader_stage(shader_stage)
	
	var shader_spirv : RDShaderSPIRV
	if debug:
		var file = FileAccess.open(shader_stage.shader_file.resource_path, FileAccess.READ)
		var split_shader : PackedStringArray = file.get_as_text().split("#[compute]", true, 1)
		var content : String = split_shader[min(1, split_shader.size() - 1)]
		var all_split_parts : PackedStringArray = content.split("#version 450", true, 1)
		content = str(all_split_parts[0],
		"#version 450
#define DEBUG
layout(rgba16f, set = 1, binding = 10) uniform image2D debug_1_image;
layout(rgba16f, set = 1, binding = 11) uniform image2D debug_2_image;
layout(rgba16f, set = 1, binding = 12) uniform image2D debug_3_image;
layout(rgba16f, set = 1, binding = 13) uniform image2D debug_4_image;
layout(rgba16f, set = 1, binding = 14) uniform image2D debug_5_image;
layout(rgba16f, set = 1, binding = 15) uniform image2D debug_6_image;
layout(rgba16f, set = 1, binding = 16) uniform image2D debug_7_image;
layout(rgba16f, set = 1, binding = 17) uniform image2D debug_8_image;",
		all_split_parts[1])
		var shader_source : RDShaderSource = RDShaderSource.new()
		shader_source.set_stage_source(RenderingDevice.SHADER_STAGE_COMPUTE, content)
		shader_spirv = rd.shader_compile_spirv_from_source(shader_source, false)
	else:
		shader_spirv = shader_stage.shader_file.get_spirv()
	
	shader_stage.shader = rd.shader_create_from_spirv(shader_spirv)
	shader_stage.pipeline = rd.compute_pipeline_create(shader_stage.shader)

#endregion
