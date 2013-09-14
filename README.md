UnityFBO
========

This project demonstrates how to make a native OpenGL Framebuffer object on iOS and pipe the resulting texture output to a Unity texture.

The code is heavily commented, and littered with GL checks, so if you run into GL errors, you should be able to track them down.

The example shows a native OpenGL texture being created and rendered to an FBO. The output from the FBO is rendered to a Unity texture. The Unity texture is then used in two different materials on two different objects in a scene.

Each frame an update is called that changes the image that goes into the FBO, causing the resulting Unity Texture to animate.
