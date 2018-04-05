# ScreenSpaceSubsurfaceScattering

![SSSS](https://raw.githubusercontent.com/Xerxes1138/ScreenSpaceSubsurfaceScattering/master/SSS.png)

# Features
- SSS (SubSurfaceScattering) blur is performed in screen space
- SSS color attenuation can be defined by a color or a texture
- Transmittance (based on the SSS color/texture)
- Can be used on all surfaces (snow for example)

# Limitations
- Deferred shading only
- Surface shaders only (existing surface shader need to be updated, see SurfaceShaderSSSTemplate.shader and  SurfaceShaderTemplate.shader as guide)
- Not working with ambient occlusion and screen space reflection from post processing stack

# Requirements

Unity 2017.2.0f3 and a shader model 3.0 ( dx9 ) graphic card.

# How to use

Set project in Linear Color space and make sure that under ProjectSettings/Graphics it is setup like the image below

![GraphicsSettings](https://raw.githubusercontent.com/Xerxes1138/ScreenSpaceSubsurfaceScattering/master/GraphicsSettings.png)

See pref_camerarig for reference on how to setup ScreenSpaceSubSurfaceScattering.cs on your camera (should always be the first effect to be used)

# References
- [Jimenez et al. 2011] "https://github.com/iryoku/separable-sss"
- [Mavridis 2012] "The Compact YCoCg Frame Buffer"
- [Sousa  2013] "The Rendering Technologies of Crysis 3"
- [Jimenez et al. 2013] "Next-Generation Character Rendering"
- [Jimenez 2014] "Next Generation Post Processing In Call Of Duty Advanced Warfare" 
- [Senua 2016] "Digital Humans"
- [Mikkel Gjøl & Mikkel Svendsen] "THE RENDERING OF INSIDE"