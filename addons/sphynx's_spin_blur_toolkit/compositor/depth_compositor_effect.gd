@tool
extends "res://addons/sphynx_enhanced_compositor_toolkit/base_classes/enhanced_compositor_effect.gd"
class_name DepthCompositorEffect

# When the depth texture has generated, this signal will be emitted
signal texture_generated(depth_texture: Texture2DRD)

# This contains our depth texture compute shader stage
@export var depth_texture_stage: ShaderStageResource = preload("res://addons/sphynx's_spin_blur_toolkit/compositor/depth_texture_stage.tres")

var texture: RID
var texture_format := RDTextureFormat.new()
var texture_changed := false


# Wrapper to _render_callback introduced by the addon 
func _render_callback_2(render_size: Vector2i, render_scene_buffers: RenderSceneBuffersRD, render_scene_data: RenderSceneDataRD):
	# Get our render size, this is the 3D render resolution!
	var size = render_scene_buffers.get_internal_size()
	if size.x == 0 and size.y == 0:
		return
	
	if not texture.is_valid() or \
			texture_format.width != size.x or \
			texture_format.height != size.y:
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
	
	# Get godot's depth buffer
	var depth_image := render_scene_buffers.get_depth_layer(0)
	
	# Define invocation group size
	@warning_ignore("integer_division")
	var x_groups := floori((render_size.x - 1) / 16 + 1)
	@warning_ignore("integer_division")
	var y_groups := floori((render_size.y - 1) / 16 + 1)
	
	# Dispatch a compute pipeline with our stage,
	# write to depth buffer based on scene
	# data buffer and depth buffer
	dispatch_stage(depth_texture_stage,
	[
		get_sampler_uniform(depth_image, 0, false),
		get_image_uniform(texture, 1),
	],
	[],
	Vector3i(x_groups, y_groups, 1),
	"DepthExtraction",
	0)


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
