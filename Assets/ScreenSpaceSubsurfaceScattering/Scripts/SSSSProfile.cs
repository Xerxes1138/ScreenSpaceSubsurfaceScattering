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

using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[System.Serializable]
public enum SamplingResolution
{
    FullRes = 1,
    HalfRes = 2,
};

[System.Serializable]
public enum DebugPass
{
    Combine,
    DiffuseLighting,
    SpecularLighting,
    Albedo,
    Specular,
    SSSColor,
    ShadingModel,
    Fade
};

[System.Serializable]
public enum SampleQuality
{
    Low = 6, // 5 + 1
    Medium = 9, // 8 + 1
    High = 13, // 12 + 1
};

[CreateAssetMenu(menuName = "Xerxes1138/ScreenSpaceSubsurfaceScattering/Profile")]
public class SSSSProfile : ScriptableObject
{
    // Debug view
    public DebugPass debugPass = DebugPass.Combine;

    // Quality settings
    public SamplingResolution samplingResolution = SamplingResolution.FullRes;

    [Range(0.0f, 1.0f)]
    public float jitterRadius = 0.25f; // 0..1
    public SampleQuality sampleQuality = SampleQuality.Medium;

    // General settings
    public bool temporalJitter = false;
    public float worldUnit = 25.0f;
    public float fadeDistance = 4.0f;
    public float fadeRadius = 1.0f;
}
