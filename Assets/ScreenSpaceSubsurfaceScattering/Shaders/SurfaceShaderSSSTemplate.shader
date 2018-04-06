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

Shader "Xerxes1138/Surface Shader Templates/Subsurface Scattering" 
{
	Properties 
	{
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
		[NoScaleOffset]_MetallicGlossMap ("Metallic (R), Smoothness (A)", 2D) = "white" {}
		[NoScaleOffset]_BumpMap ("Normal (RGB)", 2D) = "bump" {}
		[NoScaleOffset]_OcclusionMap ("Occlusion (G)", 2D) = "white" {}

		[Header(Sub Surface Scattering)]
		[NoScaleOffset]_SSSTex("SSS Color (RGB), SSS Radius (A)", 2D) = "white" {}
		_SSSColor("Color", Color) = (1.0, 0.3, 0.3,1)
		_SSSRadius ("Radius", Range(0.0, 1.0)) = 0.5

		[Header(Transmittance)]
		[NoScaleOffset]_TransmittanceTex ("Thickness", 2D) = "white" {}
		_TransmittanceExp ("Exponent", Range(1.0, 8.0)) = 1.0
		_Transmittance ("Scale", Range(0.0, 1.0)) = 1.0
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200

		CGPROGRAM
		#pragma surface surf StandardSSSS exclude_path:prepass

		// SM 3.0 is required
		#pragma target 3.0

		// Screen Space Subsurface Scattering
		#define _MATERIAL_MODEL_SSS // Define our shading model

		#include "SSSSPBSLighting.cginc"

		sampler2D _MainTex; // RGB = Diffuse or specular color
		sampler2D _BumpMap; // RGB = Normal
		sampler2D _MetallicGlossMap; // R = Metallic, A = Smoothness
		sampler2D _OcclusionMap; // G = Occlusion

		half4 _Color;
		half _Glossiness;
		half _Metallic;

		// SSS
		sampler2D _SSSTex; // RGB = SSS color, A = SSS radius
		sampler2D _TransmittanceTex; // B = Transmittance

        half4 _SSSColor;
		half _SSSRadius;
		half _Transmittance;
		half _TransmittanceExp;
					
		// Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
		// See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
		// #pragma instancing_options assumeuniformscaling
		UNITY_INSTANCING_CBUFFER_START(Props)
			// put more per-instance properties here
		UNITY_INSTANCING_CBUFFER_END

        struct Input 
		{
            float2 uv_MainTex;
            float4 screenPos; // screenPos is required for the interleaved pattern
        };

		void surf (Input IN, inout SurfaceOutputStandardSSSS o) 
		{
		    float2 screenUV = IN.screenPos.xy / max(1e-5f, IN.screenPos.w);
            int2 pos = screenUV * _ScreenParams.xy;

			half4 albedo = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			half4 metallicGloss = tex2D(_MetallicGlossMap, IN.uv_MainTex);
			metallicGloss.r *= _Metallic;
			metallicGloss.a *= _Glossiness; 
			half3 normal = UnpackNormal(tex2D(_BumpMap, IN.uv_MainTex));
			half occlusion = tex2D(_OcclusionMap, IN.uv_MainTex).g;

			half4 sssColorAndRadius = tex2D(_SSSTex, IN.uv_MainTex);
			sssColorAndRadius.rgb *= _SSSColor.rgb;
			sssColorAndRadius.a *= _SSSRadius;

			half transmittance = pow(sqrt(tex2D(_TransmittanceTex, IN.uv_MainTex).b) * _Transmittance, _TransmittanceExp) * (1.0f - metallicGloss.r);

			o.Albedo = albedo.rgb;
			o.Metallic = metallicGloss.r;
			o.Smoothness = metallicGloss.a;
			o.Normal = normal;
			o.Occlusion = occlusion;
			o.Alpha = albedo.a;

            o.SubSurfaceScatteringColorAndRadius.rgb = sssColorAndRadius.rgb;
			o.SubSurfaceScatteringColorAndRadius.a = sssColorAndRadius.a * (1.0f - metallicGloss.r);

            o.Transmittance = transmittance;

            o.Interleaved = GetPattern (pos);
		}
		ENDCG
	}
	FallBack "Diffuse"
}