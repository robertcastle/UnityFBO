using UnityEngine;
using System.Collections;

/// <summary>
/// Rotate an object around a specified a axis by degrees per second
/// </summary>
public class AxisRotate : MonoBehaviour
{	
	public Vector3 axis = Vector3.up;
	public float angle = 1.0f;
	
	// Update is called once per frame
	void Update ()
	{
		transform.Rotate(axis, angle*Time.deltaTime);
	}
}
