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

#ifndef SSSS_UTILS_INCLUDED
#define SSSS_UTILS_INCLUDED

#define SHADING_MODEL_NUM 4
#define SHADING_MODEL_STANDARD 0
#define SHADING_MODEL_SSS 1

#define PI 3.141592f

struct SurfaceParameter
{
    int		shadingModel;
    half3	diffColor;
    half3	specColor;
    half3	worldNormal;
    half	smoothness;
    half	oneMinusReflectivity;
    half	occlusion;
    half3	sssColor;
    half	sssRadius;
    half	sssMask;
    half	transmittanceMask;
    bool	pattern;
};

float Pow2(float x) { return x * x; }
float2 Pow2(float2 x) { return x * x; }
float3 Pow2(float3 x) { return x * x; }
float4 Pow2(float4 x) { return x * x; }

float Pow3(float x) { return x * x * x; }
float2 Pow3(float2 x) { return x * x * x; }
float3 Pow3(float3 x) { return x * x * x; }
float4 Pow3(float4 x) { return x * x * x; }

float Max(float color) { return max(1e-5f, color); }
float2 Max(float2 color) { return max(1e-5f, color); }
float3 Max(float3 color) { return max(1e-5f, color); }
float4 Max(float4 color) { return max(1e-5f, color); }

bool GetPattern (int2 pos)
{
    #if SHADER_TARGET < 40
		bool pattern = fmod(pos.x, 2.0f) == fmod(pos.y, 2.0f);
    #else
		bool pattern = (pos.x & 1.0f) == (pos.y & 1.0f);
    #endif

	return pattern;
}

// [Jimenez 2014] "Next Generation Post Processing In Call Of Duty Advanced Warfare"  
float InterleavedGradientNoise (float2 pos, float2 random)
{
    float3 magic = float3(0.06711056f, 0.00583715f, 52.9829189f);
    return frac(magic.z * frac(dot(pos.xy + random, magic.xy)));
}

float ColorDiffBlend (float3 a, float3 b)
{
	float3 diff = a - b;
	float length = sqrt(dot(diff, diff));
	return 1.0f / (length + 1e-3f);
}

// Ohttps://knarkowicz.wordpress.com/2014/04/16/octahedron-normal-vector-encoding/
float2 OctahedronWrap( float2 v )
{
    return ( 1.0f - abs( v.yx ) ) * ( v.xy >= 0.0f ? 1.0f : -1.0f );
}

float2 EncodeNormal( float3 n )
{
    n /= max( 1e-5f, abs( n.x ) + abs( n.y ) + abs( n.z ));
    n.xy = n.z >= 0.0f ? n.xy : OctahedronWrap( n.xy );
    n.xy = n.xy * 0.5f + 0.5f;
    return n.xy;
}

float3 DecodeNormal( float2 encN )
{
    encN = encN * 2.0f - 1.0f;
    float3 n;
    n.z = 1.0f - abs( encN.x ) - abs( encN.y );
    n.xy = n.z >= 0.0f ? encN.xy : OctahedronWrap( encN.xy );
    n = normalize( n );
    return n;
}
//

// [Lagarde, De Rousiers SIGGRAPH 2014] "Moving Frostbite to Physically Based Rendering"
float3 accurateSRGBToLinear(float3  sRGBCol)
{
    float3  linearRGBLo   = sRGBCol / 12.92f;
    float3  linearRGBHi   = pow(( sRGBCol + 0.055f) / 1.055f,  2.4f);
    float3  linearRGB     = (sRGBCol  <= 0.04045f) ? linearRGBLo : linearRGBHi;
    return  linearRGB;
}

float3 accurateLinearToSRGB(float3  linearCol)
{
    float3 sRGBLo = linearCol * 12.92f;
    float3 sRGBHi = (pow(abs(linearCol), 1.0f/2.4f) * 1.055f)  - 0.055f;
    float3 sRGB    = (linearCol  <= 0.0031308f) ? sRGBLo : sRGBHi;
    return  sRGB;
}
//

float EncodeShadingModel(int shadingModel)
{
	return (float)shadingModel / (float)SHADING_MODEL_NUM;
}

int DecodeShadingModel(float shadingModel)
{
	return int(shadingModel * (float)SHADING_MODEL_NUM + 0.5f);
}

#include "SSSSYCbCr.cginc"

half3 EncodeDiffColorAndTransmittance (bool interleaved, float3 diffColor, float transmittance)
{
    half3 diffColorYCbCr = RGBtoYCbCr(diffColor);
    diffColor.r = diffColorYCbCr.r;
    diffColor.g = (interleaved) ? diffColorYCbCr.b : diffColorYCbCr.g;
    return half3(diffColor.rg, transmittance);
}
				
half3 EncodeSpecColorAndSSSColor (bool interleaved, float3 specColor, float3 sssColor)
{
    half3 sssColorYCbCr = RGBtoYCbCr(sssColor.rgb);
    sssColor.r = sssColorYCbCr.r;
    sssColor.g = (interleaved) ? sssColorYCbCr.b : sssColorYCbCr.g;
    half specLuma = 0.25f * specColor.r + 0.5f * specColor.g + 0.25f * specColor.b;
    return half3(specLuma, sssColor.rg);
}

half3 EncodeNormalAndSSSRadius (float3 normal, float sssRadius)
{
    return half3(EncodeNormal(normal), sssRadius);
}

half3 EncodeUnityNormal (float3 normal)
{
    return normal * 0.5f + 0.5f;
}
#endif
