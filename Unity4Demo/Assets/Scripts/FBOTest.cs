using UnityEngine;
using System.Collections;

/// <summary>
/// FBO test script to show how to apply the FBO texture to materials
/// </summary>
public class FBOTest : MonoBehaviour
{
	void Start()
	{
		//Set the material's texture to the FBO texture
		renderer.material.mainTexture = FBOPlugin.GetTexture();
	}
	
	void Update()
	{
		//Send a varying value to the plugin to oscillate the Texture's colours
		float value = Mathf.Abs(Mathf.Sin(Time.time));
		FBOPlugin.Update(value);
	}
}
