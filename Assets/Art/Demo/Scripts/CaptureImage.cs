using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CaptureImage : MonoBehaviour
{
    [SerializeField]
    string imageName = string.Empty;

    private void Update()
    {
        if (Input.GetKeyDown(KeyCode.P))
        {
            ScreenCapture.CaptureScreenshot("d:/" + imageName + ".png");
        }
    }
}
