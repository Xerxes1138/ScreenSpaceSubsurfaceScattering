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

#ifndef SSSS_PBS_LIGHTING_INCLUDED
#define SSSS_PBS_LIGHTING_INCLUDED

#include "UnityShaderVariables.cginc"
#include "UnityStandardConfig.cginc"
#include "UnityLightingCommon.cginc"
#include "UnityGBuffer.cginc"
#include "UnityGlobalIllumination.cginc"
#include "UnityPBSLighting.cginc"

#include "SSSSBRDF.cginc"
#include "SSSSGBuffer.cginc"

		struct SurfaceOutputStandardSSSS
		{
            fixed3 Albedo;
            // base (diffuse or specular) color
			fixed3 Normal;
            // tangent space normal, if written
			half3 Emission;
            half Metallic;
            // 0=non-metal, 1=metal
			// Smoothness is the user facing name, it should be perceptual smoothness but user should not have to deal with it.
			// Everywhere in the code you meet smoothness it is perceptual smoothness
			half Smoothness;
            // 0=rough, 1=smooth
			half Occlusion;
            // occlusion (default 1)
			fixed Alpha;
            // alpha for transparencies

			half4 SubSurfaceScatteringColorAndRadius;
            half Transmittance;
            bool Interleaved;
        };

		inline half4 LightingStandardSSSS(SurfaceOutputStandardSSSS s, half3 viewDir, UnityGI gi)
		{
			s.Normal = normalize(s.Normal); 

			half oneMinusReflectivity;
			half3 specColor;
			s.Albedo = DiffuseAndSpecularFromMetallic (s.Albedo, s.Metallic, /*out*/ specColor, /*out*/ oneMinusReflectivity);

			// shader relies on pre-multiply alpha-blend (_SrcBlend = One, _DstBlend = OneMinusSrcAlpha)
			// this is necessary to handle transparency in physically correct way - only diffuse component gets affected by alpha
			half outputAlpha;
			s.Albedo = PreMultiplyAlpha (s.Albedo, s.Alpha, oneMinusReflectivity, /*out*/ outputAlpha);

			half4 color = 0.0f;
			color = UNITY_BRDF_PBS (s.Albedo, specColor, oneMinusReflectivity, s.Smoothness, s.Normal, viewDir, gi.light, gi.indirect);
			color.a = outputAlpha;

			return color;
		}

		inline half4 LightingStandardSSSS_Deferred (SurfaceOutputStandardSSSS s, half3 viewDir, UnityGI gi, out half4 outGBuffer0, out half4 outGBuffer1, out half4 outGBuffer2)
		{
            half oneMinusReflectivity;
            half3 specColor;
            s.Albedo = DiffuseAndSpecularFromMetallic (s.Albedo, s.Metallic, /*out*/ specColor, /*out*/ oneMinusReflectivity);

            half4 color = 0.0f;
			#ifdef _MATERIAL_MODEL_SSS
				color.rgb = SeparableSubSurfaceShading(s.Transmittance, s.SubSurfaceScatteringColorAndRadius.rgb, half3(1.0f, 1.0f, 1.0f), specColor, s.Smoothness, oneMinusReflectivity, s.Normal, gi.light.dir, gi.light.color, viewDir, s.Interleaved);
				color.rgb += SeparableSubSurfaceGI (gi.indirect, half3(1.0f, 1.0f, 1.0f), specColor, s.Smoothness, oneMinusReflectivity, s.Normal, viewDir, s.Interleaved);
			#else
				color = UNITY_BRDF_PBS (s.Albedo, specColor, oneMinusReflectivity, s.Smoothness, s.Normal, viewDir, gi.light, gi.indirect);
			#endif

            GBufferData data;
			#ifdef _MATERIAL_MODEL_SSS
				data.shadingModel						= EncodeShadingModel(SHADING_MODEL_SSS);
			#else
				data.shadingModel						= EncodeShadingModel(SHADING_MODEL_STANDARD);
			#endif

			#ifdef _MATERIAL_MODEL_SSS
				data.diffColorAndCustomData				= EncodeDiffColorAndTransmittance(s.Interleaved, s.Albedo, s.Transmittance);
			#else
				data.diffColorAndCustomData				= s.Albedo;
			#endif

			data.occlusion								= s.Occlusion;

			#ifdef _MATERIAL_MODEL_SSS
				data.specColorAndCustomData				= EncodeSpecColorAndSSSColor(s.Interleaved, specColor, s.SubSurfaceScatteringColorAndRadius.rgb);
			#else
				data.specColorAndCustomData				= specColor;
			#endif

			data.smoothness								= s.Smoothness;

			#ifdef _MATERIAL_MODEL_SSS
				data.normalAndCustomData				= EncodeNormalAndSSSRadius(s.Normal, s.SubSurfaceScatteringColorAndRadius.a);
			#else
				data.normalAndCustomData				= EncodeUnityNormal(s.Normal);
			#endif

			StandardSSSSDataToGbuffer(data, outGBuffer0, outGBuffer1, outGBuffer2);

            half4 emission = 0.0f;
			#ifdef _MATERIAL_MODEL_SSS
				emission = half4((s.Interleaved) ? s.Emission  + color.rgb : 0.0f, 1.0f);
			#else
				emission = half4(s.Emission + color.rgb, 1.0f);
			#endif

            return emission;
        }

		inline void LightingStandardSSSS_GI ( SurfaceOutputStandardSSSS s, UnityGIInput data, inout UnityGI gi)
		{
            #if defined(UNITY_PASS_DEFERRED) && UNITY_ENABLE_REFLECTION_BUFFERS
				gi = UnityGlobalIllumination(data, s.Occlusion, s.Normal);
            #else
				Unity_GlossyEnvironmentData g = UnityGlossyEnvironmentSetup(s.Smoothness, data.worldViewDir, s.Normal, lerp(unity_ColorSpaceDielectricSpec.rgb, s.Albedo, s.Metallic));
				gi = UnityGlobalIllumination(data, s.Occlusion, s.Normal, g);
            #endif
		}
#endif
