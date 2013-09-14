using UnityEngine;
using System.Collections;
using System.Runtime.InteropServices;

public static class FBOPlugin
{
	//The texture that the OpenGL FBO will render to
	static Texture2D _texture;
	
	//Our interop functions. Only active on iOS builds
#if UNITY_IOS && !UNITY_EDITOR	
	[DllImport("__Internal")]
	private static extern void InitializeTexture(int textureID);
	
	[DllImport("__Internal")]
	private static extern void UpdateTexture(float value);
#endif
	
	/// <summary>
	/// Initializes the texture, and Initializes the plugin, which sets up the FBO
	/// </summary>
	static void Initialize()
	{
		_texture = new Texture2D(1,1,TextureFormat.ARGB32, false);
		_texture.SetPixel(0,0, Color.black);

#if UNITY_IOS && !UNITY_EDITOR
		InitializeTexture(_texture.GetNativeTextureID());
		//Always call this after changing OpenGL values. Otherwise odd things happen
		GL.InvalidateState();
#endif		
	}

	/// <summary>
	/// Other scripts call this to get the texture.
	/// </summary>
	/// <returns>
	/// The texture.
	/// </returns>
	public static Texture2D GetTexture()
	{
		if (_texture == null) {
			Initialize();
		}

		return _texture;
	}
	
	/// <summary>
	/// Update the FBO content. Set a value between 0-1 to change the source texture
	/// </summary>
	/// <param name='value'>
	/// A value between 0-1
	/// </param>
	public static void Update(float value)
	{
		//Initialize the texture if needed
		if (_texture == null) {
			Initialize();
		}
		
		value = Mathf.Clamp01(value);
		
		//Update the texture
#if UNITY_IOS && !UNITY_EDITOR
		UpdateTexture(value);
		//Always call this after changing OpenGL values. Otherwise odd things happen
		GL.InvalidateState();
#endif				
	}
}
