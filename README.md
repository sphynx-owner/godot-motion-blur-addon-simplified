Sphynx's Simplified Motion Blur Toolkit
=====================================

In This Project
---------------

A cleaned and simplified implementation of the motion blur compositor effect to make it more accessible for implementation into godot.

Technical Overview
------------------



The technique I have settled on is a variation on Jean-Philippe Guertin et. al's implementation introduced in [this paper](https://research.nvidia.com/sites/default/files/pubs/2013-11_A-Fast-and/Guertin2013MotionBlur-small.pdf). 

It is robust and efficient, as well as highly configurable.

Due to missing and outright incorrect information that was present in the paper, I had a hard time recreating it myself, but then I came across an implementation by [keyjiro](https://github.com/keijiro/KinoMotion/commits?author=keijiro) called [KinoMotion](https://github.com/keijiro/KinoMotion), which was originally meant for unity, but still helped close a few holes that were present in the paper.

The main difference introduced by me is the blending heuristics, which are supposed to reflect a more physically accurate motion blur phenomenon. 

### Pre-Processing

Before the motion blur can be applied, a pre processing stage is carried out to perform a few things:

1. Add motion vectors to the skybox, as those are not available by default.
2. Add support for FSR2 supersampling. 
3. Add control and configurability to different components of the motion blur, which are camera rotation, camera motion, and object motion, separately.

This stage is carried out by the **PreBlurProcessor** compositor effect, thus it must be added before any motion blur compositor effect in the `compositor_effects` array.

![alt text](readme-assets/pre-blur-processor.png)

You can find the script at `res://addons/sphynx_motion_blur_toolkit/pre_blur_processing/pre_blur_processor.gd`.

### Guertin's motion blur

The motion blur method depicted in the article is carried out in 4 stages:

1. **Tile Max X** - In this stage, the most dominant velocity in the velocity buffer within each tile's row is stored into that tile's row in the output texture.

2. **Tile Max Y** - The most dominant velocity in the output texture from the Tile Max X stage within each tile's column is stored into a final tile as the dominant velocity of that tile.

3. **Neighbor Max** - A dominant velocity is picked from the neighboring tiles, dilating stronger velocities beyond their original tiles.

4. **Blur Reconstruction** - Combining all data textures using blending heuristics to reconstruct the blur effect in screen space.

It is carried out by the **GuertinMotionBlur** compositor effect.

![alt text](readme-assets/guertin-motion-blur.png)

You can find the script at `res://addons/sphynx_motion_blur_toolkit/guertin/guertin_motion_blur.gd`.

### Optional Debug Stage

Adding a **DebugCompositorEffect** stage at the end of the `compositor_effects` array will let you display some useful debugging as its own post process effect. By default the blur and pre processing stages contain some functionality to support it, and all they need is to have `debug` enabled on them:

![alt text](readme-assets/enable-debug.png)

Then you can press Z to toggle the debug views, X to freeze and unfreeze the frame, and C to cycle between debug view "pages" if there are any.

You can also manually control the toggles in the editor.

![alt text](readme-assets/debug-compositor-effect.png)


A Deeper Dive
-------------

### Pre Blur Processing

As mentioned above, godot is quite limited in its motion vector buffer, as it is focused on being optimized.

