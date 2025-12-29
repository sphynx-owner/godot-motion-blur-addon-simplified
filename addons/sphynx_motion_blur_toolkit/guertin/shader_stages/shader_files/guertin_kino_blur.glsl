#[compute]
#version 450

#define FLT_MAX 3.402823466e+38
#define FLT_MIN 1.175494351e-38
#define M_PI 3.1415926535897932384626433832795

layout(set = 0, binding = 0) uniform sampler2D color_sampler;
layout(set = 0, binding = 1) uniform sampler2D velocity_sampler;
layout(set = 0, binding = 2) uniform sampler2D neighbor_max;
layout(set = 0, binding = 3) uniform sampler2D tile_variance;
layout(rgba16f, set = 0, binding = 4) uniform writeonly image2D output_color;
layout(set = 0, binding = 5) uniform sampler2D custom_curve;


layout(push_constant, std430) uniform Params 
{	
	float minimum_user_threshold;
	float importance_bias;
	float maximum_jitter_value;
	float motion_blur_intensity;
	// The size in pixels of each tile. Tiles divide
	// the velocity texture into regions that contain the max velocity
	// amongst neighboring regions. This information is available in neighbor_max
	int tile_size;
	int sample_count;
	int frame;
	int nan4;
} params;

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

// McGuire's functions https://docs.google.com/document/d/1IIlAKTj-O01hcXEdGxTErQbCHO9iBmRx6oFUy_Jm0fI/edit
// ----------------------------------------------------------
float soft_depth_compare(float depth_X, float depth_Y, float sze)
{
	return clamp(1 - (depth_X - depth_Y) / sze, 0, 1);
}

float cone(float T, float v)
{
	return clamp(1 - T / v, 0, 1);
}

float cylinder(float T, float v)
{
	return 1.0 - smoothstep(0.95 * v, 1.05 * v, T);
}
// ----------------------------------------------------------

// Guertin's functions https://research.nvidia.com/sites/default/files/pubs/2013-11_A-Fast-and/Guertin2013MotionBlur-small.pdf
// ----------------------------------------------------------
float z_compare(float a, float b, float sze)
{
	return clamp(1. - sze * (a - b), 0, 1);
}
// ----------------------------------------------------------

// from https://www.shadertoy.com/view/ftKfzc
// ----------------------------------------------------------
float interleaved_gradient_noise(vec2 uv){
	uv += float(params.frame)  * (vec2(47, 17) * 0.695);

    vec3 magic = vec3( 0.06711056, 0.00583715, 52.9829189 );

    return fract(magic.z * fract(dot(uv, magic.xy)));
}
// ----------------------------------------------------------

// from https://github.com/bradparks/KinoMotion__unity_motion_blur/tree/master
// ----------------------------------------------------------
vec2 safenorm(vec2 v)
{
	float l = max(length(v), 1e-6);
	// If the vector's magnitude is smaller than half a pixel, we 
	// treat it as having 0 magnitude.
	return v / l * int(l >= 0.5);
}

vec2 jitter_tile(vec2 uvi)
{
	// generate a random angle given the pixel we are in
	float angle = interleaved_gradient_noise(uvi + vec2(2, 0)) * M_PI * 2;

	float rx = cos(angle), ry = sin(angle);

	// Return a random offset between vec2i(-1, -1) and vec2i(1, 1), 
	// divided by the neighbor_max resolution to use as a random tile
	// jitter.
	return vec2(rx, ry) / textureSize(neighbor_max, 0) / 4;
}
// ----------------------------------------------------------

void main() 
{
	// The size of the output texture
	ivec2 render_size = ivec2(textureSize(color_sampler, 0));

	// Resolution of neighbor max texture (max velocity tiles)
	ivec2 tile_render_size = ivec2(textureSize(neighbor_max, 0));

	// The pixel we are running the shader for.
	ivec2 uvi = ivec2(gl_GlobalInvocationID.xy);

	// If the pixel we are in is outside the target render's size, we 
	// exit early
	if ((uvi.x >= render_size.x) || (uvi.y >= render_size.y)) 
	{
		return;
	}

	// We convert the pixel position into a texturing sampling position
	// we add 0.5 to offset the sampling to be in the "middle" of the pixel
	// and avoid artifacts caused by bilinear interpolation.
	vec2 x = (vec2(uvi) + vec2(0.5)) / vec2(render_size);
	
	// We get some random value for the current pixel. This will be used to
	// jitter the blur sampling, and achieve smoother looking blur gradient
	// with a fraction of the sample count.
	float j = interleaved_gradient_noise(uvi) * 2. - 1.;

	// We get the neighbor-max velocity for the tile we are in, with some jitter
	// between tiles to hide seams between them.
	// We then multiply the velocity by the render size to get its magnitude
	// in pixels. We also mulitply it by the blur intensity factor.
	// TODO @sphynx-owner: figure out whether adding half a tile size to x is 
	// correct. 
	vec4 vnzw =  textureLod(neighbor_max, x + vec2(0.5) / vec2(tile_render_size) + jitter_tile(uvi), 0.0) * vec4(render_size / 2., 1, 1) * params.motion_blur_intensity;

	// We get the xy components of the max tile velocity. Velocities can have a z
	// component too (we generate it in the pre-blur processing stage for stationary
	// elements), but it is used separately and does not express itself visually in the
	// blur (it represents the movement of elements towards the camera, which means
	// they don't visually move).
	vec2 vn = vnzw.xy;

	float vn_length = length(vn);

	vec4 base_color = textureLod(color_sampler, x, 0.0);

	if(vn_length < 0.5)
	{
		imageStore(output_color, uvi, base_color);
#ifdef DEBUG
		imageStore(debug_1_image, uvi, base_color);
		imageStore(debug_2_image, uvi, vec4(vn / render_size * 2, 0, 1));
		imageStore(debug_3_image, uvi, vec4(0));
		imageStore(debug_4_image, uvi, vec4(0));
#endif
		return;
	}

	// We normalize neighbor-max velocity
	vec2 wn = safenorm(vn);

	// We get the true velocity at the current pixel, mulitplied by the motion blur intensity.
	vec4 vxzw = textureLod(velocity_sampler, x, 0.0) * vec4(render_size / 2., 1, 1) * params.motion_blur_intensity;

	// We get the xy components of the true velocity (see declaration of vn)
	vec2 vx = vxzw.xy;

	// We get the length of the true velocity
	float vx_length = max(0.5, length(vx));

	// We normalize the true velocity
	vec2 wx = safenorm(vx);

	// We get a perpendicular vector to the neighbor-max velocity.
	vec2 wp = vec2(-wn.y, wn.x);
	
	// We ensure that the perpendicular vector we get is at least somewhat 
	// facing the same direction as the true velocity.
	if(dot(wp, vx) < 0)
	{
		wp = -wp;
	}

	// We generate an "explorative" vector, which will be used to sample along for any
	// objects that should be blurred in front of the current pixel's geometry.
	vec2 wc = safenorm(mix(wp, wn, (vx_length - 0.5) / params.minimum_user_threshold));

	float zx = vxzw.w;
	
	float total_weight = params.sample_count / (params.importance_bias * vx_length);

	vec4 sum = base_color * total_weight;

	for(int i = 0; i < params.sample_count; i++)
	{
		float t = mix(-1.0, 1.0, (i + j * params.maximum_jitter_value + 1.0) / (params.sample_count + 1.0));
		
		vec2 d = ((i % 2) > 0) ? vx : vn;

		float dz = ((i % 2) > 0) ? vxzw.z : vnzw.z;

		vec2 wd = safenorm(d);

		float T = abs(t * vn_length);

		vec2 y = x + t * d / render_size;

		float wa = dot(wc, wd);
		
		vec4 vyzw = textureLod(velocity_sampler, y, 0.0) * vec4(render_size / 2, 1, 1) * params.motion_blur_intensity;
		
		vec2 vy = vyzw.xy - dz * t; 
	
		float vy_length = max(0.5, length(vy));

		float zy = vyzw.w;

		float f = z_compare(-zy, -zx, 20000);
		float b = z_compare(-zx, -zy, 20000);

		float wb = abs(dot(vy / vy_length, wd));

		float weight = 0.0;
		weight += f * cone(T, vy_length) * wb;
		weight += b * cone(T, vx_length) * wa;
		weight += cylinder(T, min(vy_length, vx_length)) * 2. * max(wa, wb);

		total_weight += weight;

		sum += weight * textureLod(color_sampler, y, 0.0);
	}

	sum /= total_weight;

	imageStore(output_color, uvi, sum);
#ifdef DEBUG
	imageStore(debug_1_image, uvi, sum);
	imageStore(debug_2_image, uvi, vec4(vn / render_size * 2, 0, 1));
	imageStore(debug_3_image, uvi, vnzw);
	imageStore(debug_4_image, uvi, vxzw);
#endif
}