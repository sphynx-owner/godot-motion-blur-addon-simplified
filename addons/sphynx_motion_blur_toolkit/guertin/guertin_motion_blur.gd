@tool
extends "res://addons/sphynx_motion_blur_toolkit/guertin/base_guertin_motion_blur.gd"
class_name GuertinMotionBlur

@export_storage var blur_stage : ShaderStageResource = preload("res://addons/sphynx_motion_blur_toolkit/guertin/shader_stages/guertin_blur_stage.tres")

@export_storage var overlay_stage : ShaderStageResource = preload("res://addons/sphynx_motion_blur_toolkit/guertin/shader_stages/guertin_overlay_stage.tres")

@export_storage var tile_max_x_stage : ShaderStageResource = preload("res://addons/sphynx_motion_blur_toolkit/guertin/shader_stages/guertin_tile_max_x_stage.tres")

@export_storage var tile_max_y_stage : ShaderStageResource = preload("res://addons/sphynx_motion_blur_toolkit/guertin/shader_stages/guertin_tile_max_y_stage.tres")

@export_storage var neighbor_max_stage : ShaderStageResource = preload("res://addons/sphynx_motion_blur_toolkit/guertin/shader_stages/guertin_neighbor_max_stage.tres")

@export_storage var tile_variance_stage : ShaderStageResource = preload("res://addons/sphynx_motion_blur_toolkit/guertin/shader_stages/guertin_tile_variance_stage.tres")

var tile_max_x : StringName = "tile_max_x"

var tile_max : StringName = "tile_max"

var neighbor_max : StringName = "neighbor_max"

var tile_variance : StringName = "tile_variance"

var custom_velocity : StringName = "custom_velocity"

var freeze : bool = false

var temp_intensity : float

var previous_time : float = 0


func _render_callback_2(render_size : Vector2i, render_scene_buffers : RenderSceneBuffersRD, render_scene_data : RenderSceneDataRD):
	var time : float = float(Time.get_ticks_msec()) / 1000
	
	var delta_time : float = time - previous_time
	
	previous_time = time
	
	temp_intensity = intensity
	
	if framerate_independent:
		var capped_frame_time : float = 1 / target_constant_framerate
		
		if !uncapped_independence:
			capped_frame_time = min(capped_frame_time, delta_time)
		
		temp_intensity = intensity * capped_frame_time / delta_time
	
	ensure_texture(tile_max_x, render_scene_buffers, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, Vector2(1. / tile_size, 1.))
	ensure_texture(tile_max, render_scene_buffers, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, Vector2(1. / tile_size, 1. / tile_size))
	ensure_texture(neighbor_max, render_scene_buffers, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, Vector2(1. / tile_size, 1. / tile_size))
	ensure_texture(tile_variance, render_scene_buffers, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, Vector2(1. / tile_size, 1. / tile_size))
	ensure_texture(custom_velocity, render_scene_buffers)
	
	rd.draw_command_begin_label("Motion Blur", Color(1.0, 1.0, 1.0, 1.0))
	
	var float_tile_max_x_push_constants: PackedFloat32Array = [
		0,
		0,
		0,
		0
	]
	var int_tile_max_x_push_constants : PackedInt32Array = [
		tile_size,
		0,
		0,
		0
	]
	var tile_max_x_push_constants_byte_array = float_tile_max_x_push_constants.to_byte_array()
	tile_max_x_push_constants_byte_array.append_array(int_tile_max_x_push_constants.to_byte_array())
	
	var float_tile_max_y_push_constants: PackedFloat32Array = [
		0,
		0,
		0,
		0
	]
	var int_tile_max_y_push_constants : PackedInt32Array = [
		tile_size,
		0,
		0,
		0
	]
	var tile_max_y_push_constants_byte_array = float_tile_max_y_push_constants.to_byte_array()
	tile_max_y_push_constants_byte_array.append_array(int_tile_max_y_push_constants.to_byte_array())
	
	var float_neighbor_max_push_constants: PackedFloat32Array = [
		0,
		0,
		0,
		0
	]
	var int_neighbor_max_push_constants : PackedInt32Array = [
		0,
		0,
		0,
		0
	]
	var neighbor_max_push_constants_byte_array = float_neighbor_max_push_constants.to_byte_array()
	neighbor_max_push_constants_byte_array.append_array(int_neighbor_max_push_constants.to_byte_array())
	
	var float_tile_variance_push_constants: PackedFloat32Array = [
		0,
		0,
		0,
		0
	]
	var int_tile_variance_push_constants : PackedInt32Array = [
		0,
		0,
		0,
		0
	]
	var tile_variance_push_constants_byte_array = float_tile_variance_push_constants.to_byte_array()
	tile_variance_push_constants_byte_array.append_array(int_tile_variance_push_constants.to_byte_array())
	
	var float_blur_push_constants: PackedFloat32Array = [
		minimum_user_threshold, 
		importance_bias,
		maximum_jitter_value, 
		temp_intensity,
	]
	var int_blur_push_constants : PackedInt32Array = [
		tile_size,
		samples,
		Engine.get_frames_drawn() % 8,
		0
	]
	var blur_push_constants_byte_array = float_blur_push_constants.to_byte_array()
	blur_push_constants_byte_array.append_array(int_blur_push_constants.to_byte_array())
	
	var view_count = render_scene_buffers.get_view_count()
	
	for view in range(view_count):
		var color_image := render_scene_buffers.get_color_layer(view)
		var depth_image := render_scene_buffers.get_depth_layer(view)
		var tile_max_x_image := render_scene_buffers.get_texture_slice(context, tile_max_x, view, 0, 1, 1)
		var tile_max_image := render_scene_buffers.get_texture_slice(context, tile_max, view, 0, 1, 1)
		var neighbor_max_image := render_scene_buffers.get_texture_slice(context, neighbor_max, view, 0, 1, 1)
		var tile_variance_image := render_scene_buffers.get_texture_slice(context, tile_variance, view, 0, 1, 1)
		var custom_velocity_image := render_scene_buffers.get_texture_slice(context, custom_velocity, view, 0, 1, 1)
		
		var x_groups := floori((render_size.x / tile_size - 1) / 16 + 1)
		var y_groups := floori((render_size.y - 1) / 16 + 1)
		
		dispatch_stage(tile_max_x_stage, 
		[
			get_sampler_uniform(custom_velocity_image, 0, false),
			get_sampler_uniform(depth_image, 1, false),
			get_image_uniform(tile_max_x_image, 2)
		],
		tile_max_x_push_constants_byte_array,
		Vector3i(x_groups, y_groups, 1), 
		"TileMaxX", 
		view)
		
		x_groups = floori((render_size.x / tile_size - 1) / 16 + 1)
		y_groups = floori((render_size.y / tile_size - 1) / 16 + 1)
		
		dispatch_stage(tile_max_y_stage, 
		[
			get_sampler_uniform(tile_max_x_image, 0, false),
			get_image_uniform(tile_max_image, 1)
		],
		tile_max_y_push_constants_byte_array,
		Vector3i(x_groups, y_groups, 1), 
		"TileMaxY", 
		view)
		
		dispatch_stage(neighbor_max_stage, 
		[
			get_sampler_uniform(tile_max_image, 0, false),
			get_image_uniform(neighbor_max_image, 1)
		],
		neighbor_max_push_constants_byte_array,
		Vector3i(x_groups, y_groups, 1), 
		"NeighborMax", 
		view)
		
		x_groups = floori((render_size.x - 1) / 16 + 1)
		y_groups = floori((render_size.y - 1) / 16 + 1)
		
		dispatch_stage(blur_stage, 
		[
			get_sampler_uniform(color_image, 0, false),
			get_sampler_uniform(custom_velocity_image, 1, false),
			get_sampler_uniform(neighbor_max_image, 2, false),
			get_sampler_uniform(tile_variance_image, 3, true),
			get_image_uniform(color_image, 4),
		],
		blur_push_constants_byte_array,
		Vector3i(x_groups, y_groups, 1), 
		"Blur Reconstruction", 
		view)
	
	rd.draw_command_end_label()
