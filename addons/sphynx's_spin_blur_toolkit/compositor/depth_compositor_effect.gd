@tool
class_name DepthCompositorEffect
extends CompositorEffect

# When the depth texture has generated, this signal will be emitted
signal texture_generated(depth_texture: Texture2DRD)

var rd: RenderingDevice
var shader: RID
var pipeline: RID

var nearest_sampler: RID

var texture: RID
var texture_format := RDTextureFormat.new()
var texture_changed := false


func _init():
	rd = RenderingServer.get_rendering_device()
	
	var sampler_state := RDSamplerState.new()
	
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	sampler_state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler_state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	
	nearest_sampler = rd.sampler_create(sampler_state)
	
	RenderingServer.call_on_render_thread(_initialize_compute)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if shader.is_valid():
			# Pipeline is a dependent that will get deleted automatically
			rd.free_rid(shader)
		
		if texture.is_valid():
			rd.free_rid(texture)
		
		if nearest_sampler.is_valid():
			rd.free_rid(nearest_sampler)


func _initialize_compute() -> void:
	rd = RenderingServer.get_rendering_device()
	
	if not rd:
		return
	
	var shader_file: RDShaderFile = load("res://addons/sphynx's_spin_blur_toolkit/compositor/depth_compositor_compute.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	
	shader = rd.shader_create_from_spirv(shader_spirv)
	
	if shader.is_valid():
		pipeline = rd.compute_pipeline_create(shader)


func _render_callback(p_effect_callback_type: EffectCallbackType, p_render_data: RenderData) -> void:
	if !rd and !pipeline.is_valid():
		return
	
	var render_scene_buffers: RenderSceneBuffersRD = p_render_data.get_render_scene_buffers()
	
	if !render_scene_buffers:
		return
	
	# Get our render size, this is the 3D render resolution!
	var size: Vector2i = render_scene_buffers.get_internal_size()
	if size.x == 0 and size.y == 0:
		return
	
	
	if not texture.is_valid() or texture_format.width != size.x or texture_format.height != size.y:
		_build_texture(size.x, size.y)
		texture_changed = true
	
	# Will be true if the texture was just generated (could already exist)
	if texture_changed:
		texture_changed = false
		
		# We create a new Texture2DRD wrapper that we can feed to surface materials
		var generated_texture: Texture2DRD = Texture2DRD.new()
		
		# And feed it the low-level depth texture's RID
		generated_texture.texture_rd_rid = texture
		
		texture_generated.emit(generated_texture)
	
	# Define invocation group size
	@warning_ignore("integer_division")
	var x_groups: int = (size.x - 1) / 16 + 1
	
	@warning_ignore("integer_division")
	var y_groups: int = (size.y - 1) / 16 + 1
	
	var z_groups: int = 1
	
	# Get godot's depth buffer
	var depth_image: RID = render_scene_buffers.get_depth_layer(0)
	
	var depth_sampler_uniform: RDUniform = RDUniform.new()
	depth_sampler_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	depth_sampler_uniform.binding = 0
	depth_sampler_uniform.add_id(nearest_sampler)
	depth_sampler_uniform.add_id(render_scene_buffers.get_depth_layer(0))
	
	var texture_uniform: RDUniform = RDUniform.new()
	texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	texture_uniform.binding = 1
	texture_uniform.add_id(texture)
	
	var uniform_set: RID = UniformSetCacheRD.get_cache(shader, 0, [depth_sampler_uniform, texture_uniform])
	
	var compute_list: int = rd.compute_list_begin()
	
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, x_groups, y_groups, z_groups)
	rd.compute_list_end()


# fetched from https://github.com/dmlary/godot-demo-sencil-buffer-compositor-effect
## Create a new color texture to use as the output for our render pipeline.
## Note: this texture must be the same size as the depth texture, so we create
## it on demand.
func _build_texture(width: int, height: int):
	print("building output texture (", width, ", ", height, ")")
	
	# create our output texture
	texture_format = RDTextureFormat.new()
	texture_format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	texture_format.width = width
	texture_format.height = height
	texture_format.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	texture_format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	
	var new_texture = rd.texture_create(texture_format, RDTextureView.new())
	
	assert(new_texture.is_valid())
	
	# free the old texture if there was one
	if texture.is_valid():
		rd.free_rid(texture)
		texture = RID()
	
	# save the new texture rid
	texture = new_texture
