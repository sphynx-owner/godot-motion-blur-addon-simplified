@tool
extends "res://addons/sphynx_enhanced_compositor_toolkit/base_classes/enhanced_compositor_effect.gd"
class_name DepthCompositorEffect

# When the depth texture has generated, this signal will be emitted
signal texture_generated(depth_texture: Texture2DRD)

# This contains our depth texture compute shader stage
@export var depth_texture_stage: ShaderStageResource = preload("res://addons/sphynx's_radial_blur_toolkit/compositor/depth_texture_stage.tres")


# Wrapper to _render_callback introduced by the addon 
func _render_callback_2(render_size: Vector2i, render_scene_buffers: RenderSceneBuffersRD, render_scene_data: RenderSceneDataRD):
	# Will be true if the texture was just generated (could already exist)
	if (ensure_texture("depth", render_scene_buffers, RenderingDevice.DataFormat.DATA_FORMAT_R32_SFLOAT)):
		# We create a new Texture2DRD wrapper that we can feed to surface materials
		var generated_texture: Texture2DRD = Texture2DRD.new()
		# And feed it the low-level depth texture's RID
		generated_texture.texture_rd_rid = render_scene_buffers.get_texture(context, "depth")
		
		texture_generated.emit(generated_texture)
	
	# Get godot's depth buffer
	var depth_image := render_scene_buffers.get_depth_layer(0)
	# Get the texture we created for depth data
	var output_depth_image := render_scene_buffers.get_texture_slice(context, "depth", 0, 0, 1, 1)
	
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
		get_image_uniform(output_depth_image, 1),
	],
	[],
	Vector3i(x_groups, y_groups, 1),
	"DepthExtraction",
	0)
