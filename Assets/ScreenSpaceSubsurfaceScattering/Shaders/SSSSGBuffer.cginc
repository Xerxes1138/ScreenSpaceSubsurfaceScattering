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

#ifndef SSSS_GBUFFER_INCLUDED
#define SSSS_GBUFFER_INCLUDED

// Standard and Cloth shading model
// Original layout : diffR, diffG, diffB, occ
// Original layout : specR, specG, specB, smoothness
// Original layout : normalX, normalY, normalZ, data.shadingModel

// SSS shading model
// diffY, diffCbCr, transmittanceMask, occ
// specY, sssColorY, sssColorCbCr, smoothness
// normalX, normalY, sssWidth, data.shadingModel

struct GBufferData
{
	half	shadingModel; // Shading model ID 0..3

	half3	diffColorAndCustomData;
	half3	specColorAndCustomData;
	half3	normalAndCustomData;

	half	occlusion;
	half	smoothness;
};

void StandardSSSSDataToGbuffer(GBufferData data, out half4 outGBuffer0, out half4 outGBuffer1, out half4 outGBuffer2)
{
	outGBuffer0 = half4(data.diffColorAndCustomData, data.occlusion);

	outGBuffer1 = half4(data.specColorAndCustomData, data.smoothness);

	outGBuffer2 = half4(data.normalAndCustomData, data.shadingModel);
}

GBufferData StandardSSSSDataFromGbuffer(half4 inGBuffer0, half4 inGBuffer1, half4 inGBuffer2)
{
	GBufferData data;

	data.diffColorAndCustomData						= inGBuffer0.rgb;
	data.occlusion									= inGBuffer0.a;

	data.specColorAndCustomData						= inGBuffer1.rgb;
	data.smoothness									= inGBuffer1.a;

	data.normalAndCustomData						= inGBuffer2.rgb;
	data.shadingModel								= inGBuffer2.a;

	return data;
}

#endif