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

using UnityEditor;
using UnityEngine;

[CustomEditor(typeof(SSSSProfile))]
public class SSSSProfileEditor : Editor
{
    SSSSProfile m_SSSSProfile;

    SerializedProperty m_debugPass;

    SerializedProperty m_sampleQuality;
    SerializedProperty m_samplingResolution;
    SerializedProperty m_jitterRadius;

    SerializedProperty m_temporalJitter;
    SerializedProperty m_worldUnit;
    SerializedProperty m_fadeDistance;
    SerializedProperty m_fadeRadius;

    private void OnEnable()
    {
        if (m_SSSSProfile == null)
            m_SSSSProfile = (SSSSProfile)target;

        m_debugPass = serializedObject.FindProperty("debugPass");

        m_sampleQuality = serializedObject.FindProperty("sampleQuality");
        m_samplingResolution = serializedObject.FindProperty("samplingResolution");

        m_jitterRadius = serializedObject.FindProperty("jitterRadius");

        m_temporalJitter = serializedObject.FindProperty("temporalJitter");
        m_worldUnit = serializedObject.FindProperty("worldUnit");
        m_fadeDistance = serializedObject.FindProperty("fadeDistance");
        m_fadeRadius = serializedObject.FindProperty("fadeRadius");
    }

    private void IndentProperty(SerializedProperty serializedProperty, GUIContent m_GUIContent)
    {
        EditorGUI.indentLevel++;
        EditorGUILayout.PropertyField(serializedProperty, m_GUIContent);
        EditorGUI.indentLevel--;
    }

    public override void OnInspectorGUI()
    {
        serializedObject.Update();

        EditorGUILayout.BeginVertical();
        EditorGUI.indentLevel++;
        Color backgroundColor = GUI.backgroundColor;

        GUIStyle box = new GUIStyle(EditorStyles.helpBox);
        EditorGUILayout.BeginHorizontal();
        GUI.backgroundColor = new Color(.5f, 0.5f, 0.5f);
        EditorGUILayout.BeginHorizontal(box);

        EditorGUILayout.LabelField("Debug Pass");

        EditorGUILayout.EndHorizontal();
        GUI.backgroundColor = backgroundColor;
        EditorGUILayout.EndHorizontal();
        {
            EditorGUILayout.PropertyField(m_debugPass, new GUIContent("Pass"));
        }
        EditorGUI.indentLevel--;
        EditorGUILayout.EndVertical();

        EditorGUILayout.BeginVertical();
        EditorGUI.indentLevel++;

        EditorGUILayout.BeginHorizontal();
        GUI.backgroundColor = new Color(.5f, 0.5f, 0.5f);
        EditorGUILayout.BeginHorizontal(EditorStyles.helpBox);
        EditorGUILayout.LabelField("Sub Surface Scattering Settings");
        EditorGUILayout.EndHorizontal();
        GUI.backgroundColor = backgroundColor;
        EditorGUILayout.EndHorizontal();
        {
            EditorGUILayout.LabelField("Quality", EditorStyles.boldLabel);
            IndentProperty(m_sampleQuality, new GUIContent("Sample amount", "Low = 11, medium = 17, high = 25."));
            IndentProperty(m_samplingResolution, new GUIContent("Resolution"));

            EditorGUILayout.LabelField("Jitter", EditorStyles.boldLabel);
            IndentProperty(m_temporalJitter, new GUIContent("Temporal", "Animate jitter through time, should be turned on if you use temporal AA."));
            IndentProperty(m_jitterRadius, new GUIContent("Spread", "Choose how far the jitter can spread."));
        }
        EditorGUI.indentLevel--;
        EditorGUILayout.EndVertical();

        EditorGUILayout.BeginVertical();
        EditorGUI.indentLevel++;

        EditorGUILayout.BeginHorizontal();
        GUI.backgroundColor = new Color(.5f, 0.5f, 0.5f);
        EditorGUILayout.BeginHorizontal(EditorStyles.helpBox);
        EditorGUILayout.LabelField("General Settings");
        EditorGUILayout.EndHorizontal();
        GUI.backgroundColor = backgroundColor;
        EditorGUILayout.EndHorizontal();
        {
            EditorGUILayout.LabelField("Scale", EditorStyles.boldLabel);
            IndentProperty(m_worldUnit, new GUIContent("World unit", "Set world scale in meter."));
     
            EditorGUILayout.LabelField("Fade", EditorStyles.boldLabel);
            IndentProperty(m_fadeDistance, new GUIContent("Distance", "At wich distance the sss can fade."));
            IndentProperty(m_fadeRadius, new GUIContent("Radius", "Radius of the fade."));
        }
        EditorGUI.indentLevel--;
        EditorGUILayout.EndVertical();

        serializedObject.ApplyModifiedProperties();
    }
}
