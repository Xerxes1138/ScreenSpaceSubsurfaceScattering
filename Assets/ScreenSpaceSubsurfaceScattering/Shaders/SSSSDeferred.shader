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

Shader "Hidden/Xerxes1138/DeferredShading" {
Properties {
	_LightTexture0 ("", any) = "" {}
	_LightTextureB0 ("", 2D) = "" {}
	_ShadowMapTexture ("", any) = "" {}
	_SrcBlend ("", Float) = 1
	_DstBlend ("", Float) = 1
}
SubShader {

// Pass 1: Lighting pass
//  LDR case - Lighting encoded into a subtractive ARGB8 buffer
//  HDR case - Lighting additively blended into floating point buffer
Pass {
	ZWrite Off
	Blend [_SrcBlend] [_DstBlend]

CGPROGRAM
#pragma target 3.0
#pragma vertex vert_deferred
#pragma fragment frag
#pragma multi_compile_lightpass
#pragma multi_compile ___ UNITY_HDR_ON

#pragma exclude_renderers nomrt

#include "UnityCG.cginc"
#include "UnityDeferredLibrary.cginc"
#include "UnityPBSLighting.cginc"
#include "UnityStandardUtils.cginc"
#include "UnityStandardBRDF.cginc"

#include "SSSSGBuffer.cginc"
#include "SSSSUtils.cginc"
#include "SSSSBRDF.cginc"

sampler2D _CameraGBufferTexture0;
sampler2D _CameraGBufferTexture1;
sampler2D _CameraGBufferTexture2;

half4 CalculateLight (unity_v2f_deferred i)
{
	float3 wpos;
	float2 uv;
	float atten, fadeDist;
	UnityLight light;
	UNITY_INITIALIZE_OUTPUT(UnityLight, light);
	UnityDeferredCalculateLightParams (i, wpos, uv, light.dir, atten, fadeDist);

	int2 pos = uv * _ScreenParams.xy;
	bool pattern = GetPattern (pos);

	float2 du = float2(1.0f / _ScreenParams.x, 0.0f);
	float2 dv = float2(0.0f, 1.0f / _ScreenParams.y);

	half4 gbuffer0 = tex2D (_CameraGBufferTexture0, uv); // diff, diff, diff, occ
	half4 gbuffer1 = tex2D (_CameraGBufferTexture1, uv); // spec/specLuma, spec/sssColorYCbCr, spec/sssColorYCbCr, smoothness/sssWidth
	half4 gbuffer2 = tex2D (_CameraGBufferTexture2, uv); // normal, normal, normal/smoothness, shadingID
	GBufferData data = StandardSSSSDataFromGbuffer(gbuffer0, gbuffer1, gbuffer2);

	SurfaceParameter surface = (SurfaceParameter)0.0f;
	surface.shadingModel = DecodeShadingModel(gbuffer2.a);
	surface.pattern = GetPattern (pos);
	surface.smoothness = data.smoothness;

	//UNITY_BRANCH
	if(surface.shadingModel == SHADING_MODEL_SSS)
	{
		surface.worldNormal = DecodeNormal(data.normalAndCustomData.rg);
		surface.diffColor = 1.0f;
		surface.specColor = data.specColorAndCustomData.rrr;

		// TODO command buffer to send sssColor as a texture to sss rendering shader and here ?
		half3 sssColor = half3(data.specColorAndCustomData.gb, 0.0f);

		float2 sssColorLeft = tex2D (_CameraGBufferTexture1, uv + du).gb;
		float2 sssColorRight = tex2D (_CameraGBufferTexture1, uv - du).gb;
		float2 sssColorTop = tex2D (_CameraGBufferTexture1, uv - dv).gb;
		float2 sssColorBottom = tex2D (_CameraGBufferTexture1, uv + dv).gb;

		sssColor.b = filter(sssColor.rg, sssColorLeft, sssColorRight, sssColorTop, sssColorBottom);
		sssColor.rgb = surface.pattern ? sssColor.rbg : sssColor.rgb;
		sssColor.rgb = YCbCrToRGB (sssColor);

		surface.transmittanceMask = data.diffColorAndCustomData.b;
		surface.sssColor = sssColor;
		surface.sssRadius = data.normalAndCustomData.b;
		surface.sssMask = surface.shadingModel == SHADING_MODEL_SSS /*&& surface.sssRadius > 0.0*/ ? 1.0f : 0.0f;
	}
	else
	{
		surface.worldNormal = normalize(data.normalAndCustomData.rgb * 2.0f - 1.0f);
		surface.diffColor = data.diffColorAndCustomData;
		surface.specColor = data.specColorAndCustomData;
	}

	light.color = _LightColor.rgb * atten;

	float3 eyeVec = normalize(wpos-_WorldSpaceCameraPos);
	half oneMinusReflectivity = 1.0f - SpecularStrength(data.specColorAndCustomData);

	UnityIndirect ind;
	UNITY_INITIALIZE_OUTPUT(UnityIndirect, ind);
	ind.diffuse = 0.0f;
	ind.specular = 0.0f;

	half4 res = 0.0f;
	res.rgb = EvaluateBRDF (surface, -eyeVec, light, ind);

	return half4(res.rgb, 1.0f);
}

#ifdef UNITY_HDR_ON
half4
#else
fixed4
#endif
frag (unity_v2f_deferred i) : SV_Target
{
	half4 c = CalculateLight(i);
	#ifdef UNITY_HDR_ON
	return c;
	#else
	return exp2(-c);
	#endif
}

ENDCG
}


// Pass 2: Final decode pass.
// Used only with HDR off, to decode the logarithmic buffer into the main RT
Pass {
	ZTest Always Cull Off ZWrite Off
	Stencil {
		ref [_StencilNonBackground]
		readmask [_StencilNonBackground]
		// Normally just comp would be sufficient, but there's a bug and only front face stencil state is set (case 583207)
		compback equal
		compfront equal
	}

CGPROGRAM
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag
#pragma exclude_renderers nomrt

sampler2D _LightBuffer;
struct v2f {
	float4 vertex : SV_POSITION;
	float2 texcoord : TEXCOORD0;
};

v2f vert (float4 vertex : POSITION, float2 texcoord : TEXCOORD0)
{
	v2f o;
	o.vertex = UnityObjectToClipPos(vertex);
	o.texcoord = texcoord.xy;
	return o;
}

fixed4 frag (v2f i) : SV_Target
{
	return -log2(tex2D(_LightBuffer, i.texcoord));
}
ENDCG 
}

}
Fallback Off
}
