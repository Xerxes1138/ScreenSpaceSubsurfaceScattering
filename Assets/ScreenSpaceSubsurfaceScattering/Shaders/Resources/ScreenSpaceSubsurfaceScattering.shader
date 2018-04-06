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

Shader "Hidden/Xerxes1138/ScreenSpaceSubsurfaceScattering" 
{ 
	Properties 
	{
		_MainTex ("Base (RGB)", 2D) = "black" {}
	}
	
	CGINCLUDE
	#include			"UnityCG.cginc"
	 
	uniform sampler2D	_CameraGBufferTexture0;
	uniform sampler2D	_CameraGBufferTexture1;
	uniform sampler2D	_CameraGBufferTexture2;
	 
	uniform sampler2D	_MainTex;
	uniform sampler2D	_DiffuseSSSTex;
	uniform sampler2D	_DiffuseTex;
	uniform sampler2D	_SpecularTex;
	uniform sampler2D	_DiffuseSpecularTex;
	uniform sampler2D	_SSSColorTex;

	uniform sampler2D	_CameraDepthTexture;
	uniform sampler2D	_BlueNoiseTex;

	uniform float4		_SSSParams; // x = jitter radius, y = distanceToProjectionWindow, z = aspect ratio correction, w = world unit
	uniform float4		_DiffuseSizeAndDiffuseTexelSize; // x = diffuse width, y = diffuse height, z = 1.0f / diffuse width, w = 1.0f/ diffuse height
	uniform float4		_ScreenSizeAndScreenTexelSize; // x = screen width, y = screen height, z = 1.0f / screen width, w = 1.0f/ screen height
	uniform float4		_JitterSizeAndOffset; // x = jitter width / screen width, y = jitter height / screen height, z = random offset, w = random offset
	uniform float4		_FadeDistanceAndRadius; // x = fade distance, y = fade radius, z = unused, w = unused
	uniform float4		_TemporalAAParams; // x = sample index, y = sample count, z = jitter offset x, w = jitter offset y

	uniform int			_SSS_NUM_SAMPLES;
	uniform int			_DebugPass;

	uniform float4x4	_ProjectionMatrix;
	uniform float4x4	_ViewProjectionMatrix;
	uniform float4x4	_InverseProjectionMatrix;
	uniform float4x4	_InverseViewProjectionMatrix;
	uniform float4x4	_WorldToCameraMatrix;
	uniform float4x4	_CameraToWorldMatrix;

	#include			"../SSSSUtils.cginc"
	#include			"../SSSSGBuffer.cginc"

	float4 SampleColor(sampler2D tex, float2 uv)
	{
		return tex2Dlod(tex, float4(uv, 0.0f, 0.0f));
	}

	float SampleRawDepth (float2 uv)
	{
		float z = SampleColor(_CameraDepthTexture, uv);
		/*#if defined(UNITY_REVERSED_Z)
			z = 1.0f - z;
		#endif*/
		return z;
	}
	
	float SampleLinearEyeDepth (float2 uv)
	{
		return LinearEyeDepth(tex2Dlod(_CameraDepthTexture, float4(uv, 0.0f, 0.0f)));
	}

	float4 SampleJitter(float2 uv)
	{
		return SampleColor(_BlueNoiseTex, uv * _JitterSizeAndOffset.xy + _JitterSizeAndOffset.zw);
	}

	void SampleGBuffer(half2 uv, out half4 gbuffer0, out half4 gbuffer1, out half4 gbuffer2)
	{
		gbuffer0 = SampleColor (_CameraGBufferTexture0, uv);
		gbuffer1 = SampleColor (_CameraGBufferTexture1, uv);
		gbuffer2 = SampleColor (_CameraGBufferTexture2, uv);
	}

	float3 ScreenToWorldSpace (float3 screenPos)
	{
		float4 worldPos = mul(_InverseViewProjectionMatrix, float4(screenPos.xy * 2.0f - 1.0f, screenPos.z, 1.0f));
		return worldPos.xyz / worldPos.w;
	}

	half DecodeSubsurfaceScatteringRadius(half radius)
	{
		return radius * 1.0f / _SSSParams.w; // Divide the sss radius by a world unit value
	}

	float4 SSSAtenuation(float distance, float3 sssColor)
	{
		float3 sssAttenuation = exp2(-Pow2(distance / (1e-3f + sssColor)));

		return float4(sssAttenuation, 1.0f);
	}

	float4 SampleSSSDiffuse(float2 uv, float4 diffuse, float depth, bool followSurface)
	{
		float4 sampledDiffuse = SampleColor(_MainTex, uv);
		float sampledDepth = SampleLinearEyeDepth(uv);

		float delta = saturate(8.0f * _SSSParams.y * abs(sampledDepth - depth));

		if(followSurface)
			sampledDiffuse = lerp(sampledDiffuse, diffuse, delta);
		
		return float4(sampledDiffuse.rgb, 1.0f);
	}

	float4 SubSuraceScattering(float2 uv, float2 offsetDirection, float sssRadius, float sssMask, float3 sssColor)
	{
		float4 diffuse = SampleColor(_MainTex, uv);

		float depth = SampleLinearEyeDepth(uv);

		float2 aspectRatioCorrection = _DiffuseSizeAndDiffuseTexelSize.zw * _DiffuseSizeAndDiffuseTexelSize.y /*_SSSParams.z*/;

		float scale = DecodeSubsurfaceScatteringRadius(sssRadius) * _SSSParams.y / depth;

		float2 step = scale * offsetDirection * sssMask;

		const float range = 2.0f;
		const float exponent = 2.0f;

		float4 jitter = SampleJitter(uv);

		float4 sssAttenuation = 0.0f;
		float4 sssWeights = 0.0f;
		float4 sssDiffuse = 0.0f;
		for (int k = 0; k < _SSS_NUM_SAMPLES; k++)
		{
			float dist = pow(range * ((float)k / _SSS_NUM_SAMPLES), exponent);

			float2 offset = dist * step;

			// Next-Generation Character Rendering Jorge Jimenez 2013	
			if (abs(dist * 1.0f / (range + 1.0f)) < _SSSParams.x)
			{
				offset = float2(dot(offset, float2(jitter.x, jitter.y)), dot(offset, float2(-jitter.z, jitter.w)));
			}

			offset *= aspectRatioCorrection;

			float2 offsetUV = uv + offset;

			sssAttenuation = SSSAtenuation(dist, sssColor);

			sssWeights += sssAttenuation;
			sssDiffuse.rgb += SampleSSSDiffuse(offsetUV, diffuse, depth, true) * sssAttenuation.rgb;
		}
		sssDiffuse.rgb = Max(sssDiffuse.rgb / sssWeights.rgb);

		return float4(sssDiffuse.rgb, sssMask);
	}

	struct VertexInput 
	{
		float4 vertex : POSITION;
		float2 texcoord : TEXCOORD;
	};

	struct VertexOutput
	{
		float4 pos : POSITION;
		float2 uv : TEXCOORD0;
	};

	VertexOutput vert( VertexInput v ) 
	{
		VertexOutput o;
		o.pos = UnityObjectToClipPos(v.vertex);
		o.uv = v.texcoord;
		return o;
	}

	#define SURFACE_SETUP(x) SurfaceParameter x = \
	SurfaceSetup(i.uv, _ScreenSizeAndScreenTexelSize);

	#define SURFACE_SSS_SETUP(x) SurfaceParameter x = \
	SurfaceSetup(i.uv, _DiffuseSizeAndDiffuseTexelSize);

	inline SurfaceParameter SurfaceSetup (float2 i_uv, float4 screenSize)
	{
		int2 pos = i_uv * screenSize.xy;

		float2 du = float2(screenSize.z, 0.0f);
		float2 dv = float2(0.0f, screenSize.w);

		half4 gbuffer0, gbuffer1, gbuffer2;
		SampleGBuffer(i_uv, gbuffer0, gbuffer1, gbuffer2);
		GBufferData data = StandardSSSSDataFromGbuffer(gbuffer0, gbuffer1, gbuffer2);

		bool pattern = GetPattern (pos);
		int shadingModel = DecodeShadingModel(data.shadingModel);
		half sssMask = shadingModel == SHADING_MODEL_SSS ? 1.0f : 0.0f;

		half3 diffColorYCbCr = half3(data.diffColorAndCustomData.rg, 0.0f);

		half2 diffColorLeft = SampleColor (_CameraGBufferTexture0, i_uv + du).rg;
		half2 diffColorRight = SampleColor (_CameraGBufferTexture0, i_uv - du).rg;
		half2 diffColorTop = SampleColor (_CameraGBufferTexture0, i_uv - dv).rg;
		half2 diffColorBottom = SampleColor (_CameraGBufferTexture0, i_uv + dv).rg;

		diffColorYCbCr.b = filter(diffColorYCbCr.rg, diffColorLeft, diffColorRight, diffColorTop, diffColorBottom);
		diffColorYCbCr.rgb = pattern ? diffColorYCbCr.rbg : diffColorYCbCr.rgb;
		diffColorYCbCr.rgb = YCbCrToRGB (diffColorYCbCr);
		 
		half3 diffColor = sssMask ? diffColorYCbCr : data.diffColorAndCustomData.rgb;
		half3 specColor = sssMask ? data.specColorAndCustomData.rrr : data.specColorAndCustomData.rgb;
		half3 sssColor = SampleColor(_SSSColorTex, i_uv);
		      
		SurfaceParameter o = (SurfaceParameter)0.0f;
		o.diffColor = diffColor;
		o.specColor = specColor;
		o.worldNormal = DecodeNormal(data.normalAndCustomData.rg);
		o.shadingModel = shadingModel;
		o.pattern = pattern;
		o.sssColor = sssColor;
		o.sssRadius = data.normalAndCustomData.b;
		o.sssMask = sssMask;
		return o;
	}

	float4 SSSBlurPass_X( VertexOutput i ) : SV_Target
	{	
		SURFACE_SSS_SETUP(s)

		return float4
		(
			SubSuraceScattering(i.uv, float2(1.0f, 0.0f), s.sssRadius, s.sssMask, s.sssColor)+ 
			SubSuraceScattering(i.uv, float2(-1.0f, 0.0f), s.sssRadius, s.sssMask, s.sssColor)
		) / 2.0f;
	}

	float4 SSSBlurPass_Y( VertexOutput i ) : SV_Target
	{	
		SURFACE_SSS_SETUP(s)

		return float4
		(
			SubSuraceScattering(i.uv, float2(0.0f, 1.0f), s.sssRadius, s.sssMask, s.sssColor)+
			SubSuraceScattering(i.uv, float2(0.0f, -1.0f), s.sssRadius, s.sssMask, s.sssColor)
		) / 2.0f;
	}

	float4 Dilation( VertexOutput i ) : SV_Target
	{	
		float2 uv = i.uv; 

		float2 du = float2(_DiffuseSizeAndDiffuseTexelSize.z, 0.0f);
		float2 dv = float2(0.0f, _DiffuseSizeAndDiffuseTexelSize.w);

		//[+du-dv, -dv, -du-dv]
		//[+du	 ,	  , -du	  ]
		//[+du+dv, +dv, -du+dv]

		//[{1,-1}, {0, -1}, {-1,-1}]
		//[{1, 0}, {0,  0}, {-1, 0}]
		//[{1, 1}, {0,  1}, {-1, 1}]

		float4 colorTopLeft = SampleColor(_MainTex, uv + du - dv);
		float4 colorTopCenter = SampleColor(_MainTex, uv - dv);
		float4 colorTopRight = SampleColor(_MainTex, uv - du - dv);
		float4 colorMiddleLeft = SampleColor(_MainTex, uv + du);
		float4 colorMiddleCenter = SampleColor(_MainTex, uv);
		float4 colorMiddleRight = SampleColor(_MainTex, uv - du);
		float4 colorBottomLeft = SampleColor(_MainTex, uv + du + dv);
		float4 colorBottomCenter = SampleColor(_MainTex,  uv + dv);
		float4 colorBottomRight = SampleColor(_MainTex, uv - du + dv);

		float4 colorMax = max(colorTopLeft, max(colorTopCenter, max(colorTopRight, max(colorMiddleLeft, max(colorMiddleCenter, max(colorMiddleRight, max(colorBottomLeft, max(colorBottomCenter, colorBottomRight))))))));
		float4 color = lerp(colorMax, colorMiddleCenter, colorMiddleCenter.a);

		return color;
	}

	float4 SSSColor( VertexOutput i ) : SV_Target
	{	
		float2 uv = i.uv;
		int2 pos = uv * _ScreenSizeAndScreenTexelSize.xy;

		float2 du = float2(_ScreenSizeAndScreenTexelSize.z, 0.0f);
		float2 dv = float2(0.0f, _ScreenSizeAndScreenTexelSize.w);

		half4 gbuffer0, gbuffer1, gbuffer2;
		SampleGBuffer(uv, gbuffer0, gbuffer1, gbuffer2);
		GBufferData data = StandardSSSSDataFromGbuffer(gbuffer0, gbuffer1, gbuffer2);

		bool pattern = GetPattern (pos);
		int shadingModel = DecodeShadingModel(data.shadingModel);
		half sssMask = shadingModel == SHADING_MODEL_SSS ? 1.0f : 0.0f;

		half2 sssColorLeft = SampleColor (_CameraGBufferTexture1, i.uv - du).gb;
		half2 sssColorRight = SampleColor (_CameraGBufferTexture1, i.uv + du).gb;
		half3 sssColor = half3(data.specColorAndCustomData.gb, 0.0f);
		half2 sssColorTop = SampleColor (_CameraGBufferTexture1, i.uv - dv).gb;
		half2 sssColorBottom = SampleColor (_CameraGBufferTexture1, i.uv + dv).gb;

		sssColor.b = filter(sssColor.rg, sssColorLeft, sssColorRight, sssColorTop, sssColorBottom);
		sssColor.rgb = pattern ? sssColor.rbg : sssColor.rgb;
		sssColor.rgb = YCbCrToRGB (sssColor);

		return float4(sssColor, sssMask);
	}

	float4 Combine( VertexOutput i ) : SV_Target
	{	
		SURFACE_SETUP(s)

		float2 uv = i.uv;

		float depth = SampleRawDepth(uv);
		float3 screenPos = float3(uv, depth);
		float3 worldPos = ScreenToWorldSpace(screenPos);

		float4 sceneColor = SampleColor(_MainTex, uv);
		float4 specular = SampleColor(_SpecularTex, uv);
		float4 diffuse = SampleColor(_DiffuseTex, uv);
		float4 diffuseSSS = SampleColor(_DiffuseSSSTex, uv);
	
		float len = length(_WorldSpaceCameraPos - worldPos);
		float fade = saturate((len - _FadeDistanceAndRadius.x) / _FadeDistanceAndRadius.y);
		float3 diffLerp = lerp(diffuseSSS, diffuse, fade); // SSS is visible for only a few meters so we remove it at a user define distance, it also helps to keep details in the distance when using half res resolve

		sceneColor.rgb = lerp(sceneColor.rgb, s.diffColor * diffLerp + specular, s.sssMask);

		return half4(sceneColor.rgb, 1.0f);
	}

	void DiffuseSpecularPass
	(	
		VertexOutput i,
		out half4 outDiffuse : SV_Target0, 
		out half4 outSpecular : SV_Target1
	) 
	{	
		outDiffuse = 0.0f;
		outSpecular = 0.0f;

		SURFACE_SETUP(s)

		float2 uv = i.uv;
		int2 pos = uv * _ScreenSizeAndScreenTexelSize.xy;

		float2 du = float2(_ScreenSizeAndScreenTexelSize.z, 0.0f);
		float2 dv = float2(0.0f, _ScreenSizeAndScreenTexelSize.w);

		float3 diffSpecLeft = SampleColor(_DiffuseSpecularTex, uv - du);
		float3 diffSpecRight = SampleColor(_DiffuseSpecularTex, uv + du);
		float4 diffSpecCenter = SampleColor(_DiffuseSpecularTex, uv);
		float3 diffSpecTop = SampleColor(_DiffuseSpecularTex, uv - dv);
		float3 diffSpecBottom = SampleColor(_DiffuseSpecularTex, uv + dv);

		float ab = ColorDiffBlend (diffSpecLeft, diffSpecRight);
		float cd = ColorDiffBlend (diffSpecTop, diffSpecBottom);

		float3 diffSpec = 0.5f * lerp(diffSpecLeft + diffSpecRight, diffSpecTop + diffSpecBottom, ab < cd);

		outDiffuse.rgb = lerp(diffSpec.rgb, diffSpecCenter.rgb, s.pattern);
		outDiffuse.a = s.sssMask;

		outSpecular.rgb = lerp(diffSpecCenter.rgb, diffSpec.rgb, s.pattern);
		outSpecular.a = s.sssMask;
	}

	float4 PrePass ( VertexOutput i ) : SV_Target
	{	
		SURFACE_SETUP(s)

		float2 uv = i.uv;

		float4 sceneColor = SampleColor(_MainTex, uv);
		sceneColor.rgb *= s.sssMask; // Make sure nothing else but skin is taken
		sceneColor.a = s.sssMask;

		return Max(sceneColor);
	}

	float4 Compute(VertexOutput i) : SV_Target
	{
		float2 uv = i.uv;

		float4 sceneColor = SampleColor(_MainTex, uv);

		return Max(sceneColor);
	}

	half4 Debug( VertexOutput i ) : SV_Target
	{	
		SURFACE_SETUP(s)

		float2 uv = i.uv;

		float depth = SampleRawDepth(uv);
		float3 screenPos = float3(uv, depth);
		float3 worldPos = ScreenToWorldSpace(screenPos);

		half4 sceneColor = SampleColor(_MainTex, uv); 
		half4 specular = SampleColor(_SpecularTex, uv);
		half4 diffuse = SampleColor(_DiffuseTex, uv);
		half4 diffuseSSS = SampleColor(_DiffuseSSSTex, uv);

		if(_DebugPass == 0)
			sceneColor.rgb = 0.0;
		else if(_DebugPass == 1)
			sceneColor.rgb = lerp(diffuse.rgb, diffuseSSS.rgb, s.sssMask);
		else if(_DebugPass == 2)
			sceneColor.rgb = lerp(0.0, specular, s.sssMask);
		else if(_DebugPass == 3)
			sceneColor.rgb = s.diffColor;
		else if(_DebugPass == 4)
			sceneColor.rgb = s.specColor;
		else if(_DebugPass == 5)
			sceneColor.rgb = lerp(0.0, s.sssColor, s.sssMask);
		else if(_DebugPass == 6)
		{
			if(s.shadingModel == SHADING_MODEL_STANDARD) // 0
				sceneColor.rgb = half4(1.0f, 0.0f, 0.0f, 1.0f);
			else if(s.shadingModel == SHADING_MODEL_SSS) // 1
				sceneColor.rgb = half4(0.0f, 1.0f, 0.0f, 1.0f);
			else
				sceneColor.rgb = half4(0.0f, 0.0f, 1.0f, 1.0f);
		}
		else if (_DebugPass == 7)
		{
			float len = length(_WorldSpaceCameraPos - worldPos);
			float fade = saturate((len - _FadeDistanceAndRadius.x) / _FadeDistanceAndRadius.y);

			sceneColor.rgb = 1.0f - fade;
		}

		return half4(sceneColor.rgb, 1.0);
	}

	ENDCG 
	
	Subshader 
	{
		//0
		Pass 
		{
			ZTest Always Cull Off ZWrite Off
			Fog { Mode off }
			CGPROGRAM
			#pragma target 3.0 

			#pragma vertex vert
			#pragma fragment Combine
			
			ENDCG
		}
		//1
		Pass 
		{
			ZTest Always Cull Off ZWrite Off
			Fog { Mode off }
			CGPROGRAM
			#pragma target 3.0 

			#pragma vertex vert
			#pragma fragment DiffuseSpecularPass
			
			ENDCG
		}
		//2
		Pass 
		{
			ZTest Always Cull Off ZWrite Off
			Fog { Mode off }
			CGPROGRAM
			#pragma target 3.0 

			#pragma vertex vert
			#pragma fragment Debug
			
			ENDCG
		}
		//3
		Pass 
		{
			ZTest Always Cull Off ZWrite Off
			Fog { Mode off }
			CGPROGRAM
			#pragma target 3.0 

			#pragma vertex vert
			#pragma fragment SSSBlurPass_X
			
			ENDCG
		}
		//4
		Pass 
		{
			ZTest Always Cull Off ZWrite Off
			Fog { Mode off }
			CGPROGRAM
			#pragma target 3.0

			#pragma vertex vert
			#pragma fragment SSSBlurPass_Y
			
			ENDCG
		}
		//5
		Pass 
		{
			ZTest Always Cull Off ZWrite Off
			Fog { Mode off }
			CGPROGRAM
			#pragma target 3.0 

			#pragma vertex vert
			#pragma fragment Dilation
			
			ENDCG
		}
		//6
		Pass 
		{
			ZTest Always Cull Off ZWrite Off
			Fog { Mode off }
			CGPROGRAM
			#pragma target 3.0 

			#pragma vertex vert
			#pragma fragment PrePass
			
			ENDCG
		}
		//7
		Pass 
		{
			ZTest Always Cull Off ZWrite Off
			Fog { Mode off }
			CGPROGRAM
			#pragma target 3.0 

			#pragma vertex vert
			#pragma fragment SSSColor
			
			ENDCG
		}
		//8
			Pass
		{
			ZTest Always Cull Off ZWrite Off
			Fog{ Mode off }
			CGPROGRAM
#pragma target 3.0 

#pragma vertex vert
#pragma fragment Compute

			ENDCG
		}
	}
	Fallback Off
}