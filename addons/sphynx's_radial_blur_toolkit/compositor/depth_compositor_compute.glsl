#[compute]
#version 450

#define FLT_MAX 3.402823466e+38
#define FLT_MIN 1.175494351e-38

// A samplre to Godot's depth texture
layout(set = 0, binding = 0) uniform sampler2D depth_sampler;
// An output image we created for this
layout(set = 0, binding = 1) uniform writeonly image2D position_output;

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

void main() 
{
	// Get the size of the depth sampler image, equivalent to render size
	ivec2 render_size = ivec2(textureSize(depth_sampler, 0));

	// Get the pixel we are in
	ivec2 uvi = ivec2(gl_GlobalInvocationID.xy);

	// If this pixel is outside the image, return
	if ((uvi.x >= render_size.x) || (uvi.y >= render_size.y)) 
	{
		return;
	}

	// Feed the final position into our output position texture
	imageStore(position_output, uvi, texelFetch(depth_sampler, uvi, 0));
}