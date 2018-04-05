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

#ifndef SSSS_YCBCR_INCLUDED
#define SSSS_YCBCR_INCLUDED

//http://www.pmavridis.com/research/fbcompression/
//Returns the missing chrominance (Co or Cg) of a pixel.
//a1-a4 are the 4 neighbors of the center pixel a0.
float filter(float2 center, float2 a1, float2 a2, float2 a3, float2 a4)
{
	float4 lum = float4(a1.x, a2.x , a3.x, a4.x);
	float4 w = 1.0f-step(0.117647f, abs(lum - center.x));
	float W = w.x + w.y + w.z + w.w;
	//Handle the special case where all the weights are zero.
	//In HDR scenes it's better to set the chrominance to zero. 
	//Here we just use the chrominance of the first neighbor.
	w.x = (W == 0.0f) ? 1.0f : w.x; 
	W = (W == 0.0f) ? 1.0f : W;
	return (w.x * a1.y + w.y * a2.y + w.z * a3.y + w.w * a4.y) / W;
}

float3 RGBtoYCbCr (float3 rgb)
{
	rgb = max(accurateLinearToSRGB(rgb), 1e-5f); //max(pow(rgb, 1/2.2), 1e-5);

	return float3
	( 
		0.25f * rgb.r + 0.5f * rgb.g + 0.25f * rgb.b, 
		0.5f * rgb.r - 0.5f * rgb.b + 0.5f, 
		- 0.25f * rgb.r + 0.5f * rgb.g - 0.25f * rgb.b + 0.5f
	);
}

float3 YCbCrToRGB (float3 YCbCr)
{
	YCbCr.y -= 0.5f;
	YCbCr.z -= 0.5f;

	YCbCr = float3
	(
		YCbCr.r + YCbCr.g - YCbCr.b,
		YCbCr.r + YCbCr.b,
		YCbCr.r - YCbCr.g - YCbCr.b
	);

	YCbCr = accurateSRGBToLinear(YCbCr); // pow(YCbCr, 2.2);

	return max(YCbCr, 1e-5f);
}

#endif
