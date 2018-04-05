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

Shader "Hidden/Xerxes1138/DeferredReflections" {
Properties {
	_SrcBlend ("", Float) = 1
	_DstBlend ("", Float) = 1
}
SubShader {

// Calculates reflection contribution from a single probe (rendered as cubes) or default reflection (rendered as full screen quad)
Pass {
	ZWrite Off
	ZTest LEqual
	Blend [_SrcBlend] [_DstBlend]
CGPROGRAM
#pragma target 3.0
#pragma vertex vert_deferred
#pragma fragment frag

#include "UnityCG.cginc"
#include "UnityDeferredLibrary.cginc"
#include "UnityPBSLighting.cginc"
#include "UnityStandardUtils.cginc"
#include "UnityStandardBRDF.cginc"

#include "SSSSBRDF.cginc"
#include "SSSSUtils.cginc"
#include "SSSSGBuffer.cginc"

sampler2D _CameraGBufferTexture0;
sampler2D _CameraGBufferTexture1;
sampler2D _CameraGBufferTexture2;

half3 distanceFromAABB(half3 p, half3 aabbMin, half3 aabbMax)
{
	return max(max(p - aabbMax, aabbMin - p), half3(0.0f, 0.0f, 0.0f));
}

half4 frag (unity_v2f_deferred i) : SV_Target
{
	// Stripped from UnityDeferredCalculateLightParams, refactor into function ?
	i.ray = i.ray * (_ProjectionParams.z / i.ray.z);
	float2 uv = i.uv.xy / i.uv.w;

	int2 pos = uv * _ScreenParams;

	// read depth and reconstruct world position
	float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);
	depth = Linear01Depth (depth);
	float4 viewPos = float4(i.ray * depth, 1.0f);
	float3 worldPos = mul (unity_CameraToWorld, viewPos).xyz;

	half4 gbuffer0 = tex2D (_CameraGBufferTexture0, uv); // diff, diff, diff, occ
	half4 gbuffer1 = tex2D (_CameraGBufferTexture1, uv); // spec/specLuma, spec/sssColorYCbCr, spec/sssColorYCbCr, smoothness/sssWidth
	half4 gbuffer2 = tex2D (_CameraGBufferTexture2, uv); // normal, normal, normal/smoothness, shadingID
	GBufferData data = StandardSSSSDataFromGbuffer(gbuffer0, gbuffer1, gbuffer2);

	SurfaceParameter surface = (SurfaceParameter)0.0f;
	surface.shadingModel = DecodeShadingModel(gbuffer2.a);
	surface.pattern = GetPattern (pos);

	surface.occlusion = data.occlusion;
	surface.smoothness = data.smoothness;

	UNITY_BRANCH
	if(surface.shadingModel == SHADING_MODEL_SSS)
	{
		surface.worldNormal = DecodeNormal(data.normalAndCustomData.rg);
		surface.diffColor = 1.0f;
		surface.specColor = data.specColorAndCustomData.rrr;
		surface.sssRadius = data.normalAndCustomData.b;
		surface.sssMask = surface.shadingModel == SHADING_MODEL_SSS /*&& surface.sssRadius > 0.0*/ ? 1.0f : 0.0f;
	}
	else
	{
		surface.worldNormal = normalize(data.normalAndCustomData.rgb * 2.0f - 1.0f);
		surface.diffColor = data.diffColorAndCustomData;
		surface.specColor = data.specColorAndCustomData;
	}

	half occlusion = surface.occlusion;
	half smoothness = surface.smoothness;
	float3 eyeVec = normalize(worldPos - _WorldSpaceCameraPos);
	half3 worldNormal = surface.worldNormal;

	half3 worldNormalRefl = reflect(eyeVec, worldNormal);
	float blendDistance = unity_SpecCube1_ProbePosition.w; // will be set to blend distance for this probe
	#if UNITY_SPECCUBE_BOX_PROJECTION
		// For box projection, use expanded bounds as they are rendered; otherwise
		// box projection artifacts when outside of the box.
		float4 boxMin = unity_SpecCube0_BoxMin - float4(blendDistance,blendDistance,blendDistance,0.0f);
		float4 boxMax = unity_SpecCube0_BoxMax + float4(blendDistance,blendDistance,blendDistance,0.0f);
		half3 worldNormal0 = BoxProjectedCubemapDirection (worldNormalRefl, worldPos, unity_SpecCube0_ProbePosition, boxMin, boxMax);
	#else
		half3 worldNormal0 = worldNormalRefl;
	#endif

	Unity_GlossyEnvironmentData g;
	g.roughness		= 1.0f - smoothness;
	g.reflUVW		= worldNormal0;

	half3 env0 = Unity_GlossyEnvironment (UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, g);

	UnityLight light;
	light.color = 0.0f;
	light.dir = 0.0f;
	light.ndotl = 0.0f;

	UnityIndirect ind;
	ind.diffuse = 0.0f;
	ind.specular = env0 * occlusion;

	half3 rgb = EvaluateBRDF (surface, -eyeVec, light, ind);

	// Calculate falloff value, so reflections on the edges of the probe would gradually blend to previous reflection.
	// Also this ensures that pixels not located in the reflection probe AABB won't
	// accidentally pick up reflections from this probe.
	half3 distance = distanceFromAABB(worldPos, unity_SpecCube0_BoxMin.xyz, unity_SpecCube0_BoxMax.xyz);
	half falloff = saturate(1.0f - length(distance)/blendDistance);
	return half4(rgb, falloff);
}

ENDCG
}

// Adds reflection buffer to the lighting buffer
Pass
{
	ZWrite Off
	ZTest Always
	Blend [_SrcBlend] [_DstBlend]

	CGPROGRAM
		#pragma target 3.0
		#pragma vertex vert
		#pragma fragment frag
		#pragma multi_compile ___ UNITY_HDR_ON

		#include "UnityCG.cginc"

		sampler2D _CameraReflectionsTexture;

		struct v2f {
			float2 uv : TEXCOORD0;
			float4 pos : SV_POSITION;
		};

		v2f vert (float4 vertex : POSITION)
		{
			v2f o;
			o.pos = UnityObjectToClipPos(vertex);
			o.uv = ComputeScreenPos (o.pos).xy;
			return o;
		}

		half4 frag (v2f i) : SV_Target
		{
			half4 c = tex2D (_CameraReflectionsTexture, i.uv);
			#ifdef UNITY_HDR_ON
			return float4(c.rgb, 0.0f);
			#else
			return float4(exp2(-c.rgb), 0.0f);
			#endif

		}
	ENDCG
}

}
Fallback Off
}
