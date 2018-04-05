//MIT License
//
//Copyright(c) 2018 Charles Thomas
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files(the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions :
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.
//

#ifndef SSSS_BRDF_INCLUDED
#define SSSS_BRDF_INCLUDED

#include "UnityCG.cginc"
#include "UnityStandardConfig.cginc"
#include "UnityLightingCommon.cginc"

#include "SSSSUtils.cginc"

half3 Transmittance(half transmittanceMask, half3 sssColor, half3 lightDir, half3 normal, half3 viewDir)
{
	half3 lll = normalize(lightDir + normal * 0.1f);
	half VdotL = saturate(dot(viewDir, -lll));
	half thickness = 1.0f - (VdotL * transmittanceMask);
	
	//return exp((thickness) * half3( -8, -40, -64 ) ); // ref
	return exp(-(thickness * thickness)) * sssColor * (1.0 - thickness);
}

half3 SeparableSubSurfaceShading (half transmittanceMask, half3 sssColor, half3 diffColor, half3 specColor, half smoothness, half oneMinusReflectivity, half3 normal, half3 lightDir, half3 lightColor, half3 viewDir, bool pattern)
{
	half perceptualRoughness = SmoothnessToPerceptualRoughness (smoothness);
	half3 halfDir = Unity_SafeNormalize (lightDir + viewDir);

#if UNITY_HANDLE_CORRECTLY_NEGATIVE_NDOTV
	half shiftAmount = dot(normal, viewDir);
	normal = shiftAmount < 0.0f ? normal + viewDir * (-shiftAmount + 1e-5f) : normal;

	half nv = saturate(dot(normal, viewDir));
#else
	half nv = abs(dot(normal, viewDir));
#endif

	half nl = saturate(dot(normal, lightDir));
	half nh = saturate(dot(normal, halfDir));

	half lv = saturate(dot(lightDir, viewDir));
	half lh = saturate(dot(lightDir, halfDir));

	half diffuseTerm = DisneyDiffuse(nv, nl, lh, perceptualRoughness) * nl;

	half roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
#if UNITY_BRDF_GGX
	half V = SmithJointGGXVisibilityTerm (nl, nv, roughness);
	half D = GGXTerm (nh, roughness);
#else
	half V = SmithBeckmannVisibilityTerm (nl, nv, roughness);
	half D = NDFBlinnPhongNormalizedTerm (nh, PerceptualRoughnessToSpecPower(perceptualRoughness));
#endif

	half specularTerm = V*D * UNITY_PI;

#	ifdef UNITY_COLORSPACE_GAMMA
		specularTerm = sqrt(max(1e-4h, specularTerm));
#	endif

	specularTerm = max(0.0f, specularTerm * nl);
#if defined(_SPECULARHIGHLIGHTS_OFF)
	specularTerm = 0.0f;
#endif

	specularTerm *= any(specColor) ? 1.0f : 0.0f;

	half3 transmittance = Transmittance(transmittanceMask, sssColor, lightDir, normal, viewDir); 

	return (pattern) ? diffColor * lightColor * diffuseTerm + transmittance * lightColor : specularTerm * lightColor * FresnelTerm (specColor, lh);
}

half3 StandardShading (half3 diffColor, half3 specColor, half smoothness, half oneMinusReflectivity, half3 normal, half3 lightDir, half3 lightColor, half3 viewDir)
{
	half perceptualRoughness = SmoothnessToPerceptualRoughness (smoothness);
	half3 halfDir = Unity_SafeNormalize (lightDir + viewDir);

	#if UNITY_HANDLE_CORRECTLY_NEGATIVE_NDOTV
		half shiftAmount = dot(normal, viewDir);
		normal = shiftAmount < 0.0f ? normal + viewDir * (-shiftAmount + 1e-5f) : normal;

		half nv = saturate(dot(normal, viewDir));
	#else
		half nv = abs(dot(normal, viewDir));
	#endif

		half nl = saturate(dot(normal, lightDir));
		half nh = saturate(dot(normal, halfDir));

		half lv = saturate(dot(lightDir, viewDir));
		half lh = saturate(dot(lightDir, halfDir));

		half diffuseTerm = DisneyDiffuse(nv, nl, lh, perceptualRoughness) * nl;

		half roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
	#if UNITY_BRDF_GGX
		half V = SmithJointGGXVisibilityTerm (nl, nv, roughness);
		half D = GGXTerm (nh, roughness);
	#else
		half V = SmithBeckmannVisibilityTerm (nl, nv, roughness);
		half D = NDFBlinnPhongNormalizedTerm (nh, PerceptualRoughnessToSpecPower(perceptualRoughness));
	#endif

		half specularTerm = V*D * UNITY_PI;

	#	ifdef UNITY_COLORSPACE_GAMMA
			specularTerm = sqrt(max(1e-4h, specularTerm));
	#	endif

		specularTerm = max(0.0f, specularTerm * nl);
	#if defined(_SPECULARHIGHLIGHTS_OFF)
		specularTerm = 0.0f;
	#endif

		half surfaceReduction;
	#	ifdef UNITY_COLORSPACE_GAMMA
			surfaceReduction = 1.0f-0.28f*roughness*perceptualRoughness;
	#	else
			surfaceReduction = 1.0f / (roughness*roughness + 1.0f);
	#	endif

		specularTerm *= any(specColor) ? 1.0f : 0.0f;

		half grazingTerm = saturate(smoothness + (1.0f-oneMinusReflectivity));
		half3 color =	diffColor * lightColor * diffuseTerm +
						specularTerm * lightColor * FresnelTerm (specColor, lh);

	return half4(color, 1.0f);
}

half3 StandardGI (UnityIndirect gi, half3 diffColor, half3 specColor, half smoothness, half oneMinusReflectivity, half3 normal, half3 viewDir)
{
	half perceptualRoughness = SmoothnessToPerceptualRoughness (smoothness);

#if UNITY_HANDLE_CORRECTLY_NEGATIVE_NDOTV
	half shiftAmount = dot(normal, viewDir);
	normal = shiftAmount < 0.0f ? normal + viewDir * (-shiftAmount + 1e-5f) : normal;

	half nv = saturate(dot(normal, viewDir));
#else
	half nv = abs(dot(normal, viewDir));
#endif

	half roughness = PerceptualRoughnessToRoughness(perceptualRoughness);

	half surfaceReduction;
#	ifdef UNITY_COLORSPACE_GAMMA
		surfaceReduction = 1.0f-0.28f*roughness*perceptualRoughness;
#	else
		surfaceReduction = 1.0f / (roughness*roughness + 1.0f);
#	endif

	half grazingTerm = saturate(smoothness + (1.0f-oneMinusReflectivity));

	return gi.diffuse * diffColor + surfaceReduction * gi.specular * FresnelLerp (specColor, grazingTerm, nv); 
}

half3 SeparableSubSurfaceGI (UnityIndirect gi, half3 diffColor, half3 specColor, half smoothness, half oneMinusReflectivity, half3 normal, half3 viewDir, bool pattern)
{
	half perceptualRoughness = SmoothnessToPerceptualRoughness (smoothness);

#if UNITY_HANDLE_CORRECTLY_NEGATIVE_NDOTV
	half shiftAmount = dot(normal, viewDir);
	normal = shiftAmount < 0.0f ? normal + viewDir * (-shiftAmount + 1e-5f) : normal;

	half nv = saturate(dot(normal, viewDir));
#else
	half nv = abs(dot(normal, viewDir));
#endif

	half roughness = PerceptualRoughnessToRoughness(perceptualRoughness);

	half surfaceReduction;
	#ifdef UNITY_COLORSPACE_GAMMA
		surfaceReduction = 1.0f-0.28f*roughness*perceptualRoughness;
	#else
		surfaceReduction = 1.0f / (roughness*roughness + 1.0f);
	#endif

	half grazingTerm = saturate(smoothness + (1.0f-oneMinusReflectivity));

	return (pattern) ? gi.diffuse * diffColor : surfaceReduction * gi.specular * FresnelLerp (specColor, grazingTerm, nv);
}

half3 ShadingModel (SurfaceParameter surface, half3 V, UnityLight light)
{
	if(surface.shadingModel == SHADING_MODEL_STANDARD)
		return StandardShading (surface.diffColor, surface.specColor, surface.smoothness, surface.oneMinusReflectivity, surface.worldNormal, light.dir, light.color, V);
	else if (surface.shadingModel == SHADING_MODEL_SSS)
		return SeparableSubSurfaceShading (surface.transmittanceMask, surface.sssColor, half3(1.0f, 1.0f, 1.0f), surface.specColor, surface.smoothness, surface.oneMinusReflectivity, surface.worldNormal, light.dir, light.color, V, surface.pattern);
	else
		return 0.0f;
}

half3 ShadingModelGI (SurfaceParameter surface, half3 V, UnityIndirect gi)
{
	if(surface.shadingModel == SHADING_MODEL_STANDARD)
		return StandardGI (gi, surface.diffColor, surface.specColor, surface.smoothness, surface.oneMinusReflectivity, surface.worldNormal, V);
	else if (surface.shadingModel == SHADING_MODEL_SSS)
		return SeparableSubSurfaceGI (gi, half3(1.0f, 1.0f, 1.0f), surface.specColor, surface.smoothness, surface.oneMinusReflectivity, surface.worldNormal, V, surface.pattern);
	else
		return 0.0f;
}

half4 EvaluateBRDF (SurfaceParameter surface, half3 V, UnityLight light, UnityIndirect gi)
{
	if(0)
	{
		if(surface.shadingModel == SHADING_MODEL_STANDARD)
			return half4(1.0f, 0.0f, 0.0f, 1.0f);
		else if (surface.shadingModel == SHADING_MODEL_SSS)
			return half4(0.0f, 1.0f, 0.0f, 1.0f);
		else
			return half4(0.0f, 0.0f, 0.0f, 0.0f);
	}
	else
	{
		half4 outColor = 0.0f;
		outColor.rgb =	
		
		ShadingModel (surface, V, light) +		
		ShadingModelGI(surface, V, gi);

		outColor.a = 1.0f;

		return outColor;
	}
}

#endif
