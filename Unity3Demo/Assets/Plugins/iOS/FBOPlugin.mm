//
//  FBOPlugin.m
//  FBOPlugin
//
//  Created by Robert Castle on 13/09/2013.
//  Copyright (c) 2013 Egomotion Limited. All rights reserved.
//
//  This example shows how to make an OpenGL FBO, render content into it and
//  output it to a Unity Texture2D.
//
//  There are a lot of comments and GL checks. You can strip them all,
//  but if you start tinkering it is very helpful to catch those GL errors as early
//  as possible to track them down.
//

#import "FBOPlugin.h"

#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

//Hard coded source texture sizes, also the FBO size. You can change this, and make it dynamic
#define TEXTURE_WIDTH 8
#define TEXTURE_HEIGHT 8


#pragma mark - GL Debugging helpers

#define ENABLE_GLES_DEBUG 1

#if ENABLE_GLES_DEBUG
void GLCheckError(const char* file, int line)
{
	GLenum e = glGetError();
  
	if( e )
	{
		printf("OpenGLES error 0x%04X in %s:%i\n", e, file, line);
	}
}

#define GLESAssert()	do { GLCheckError (__FILE__, __LINE__); } while(0)
#define GLES_CHK(expr)	do { {expr;} GLESAssert(); } while(0)
#else
#define GLESAssert()	do { } while(0)
#define GLES_CHK(expr)	do { expr; } while(0)
#endif

#pragma mark - GL Attributes and Uniforms

enum {
  ATTRIB_VERTEX,
  ATTRIB_TEXTUREPOSITON,
  NUM_ATTRIBUTES
};

enum
{
  UNIFORM_TEXTURE,
  NUM_UNIFORMS
};


#pragma mark - Interop code

void InitializeTexture(int textureID)
{
  [[FBOPlugin shared] initializeTexture:textureID];
}

void UpdateTexture(float value)
{
  [[FBOPlugin shared] updateTexture:value];
}


#pragma mark - The main singleton class

@implementation FBOPlugin
{
  GLuint _sourceTexture;            // The source texture that is drawn into the FBO
  GLuint _unityTexture;             // The texture ID from Unity
  GLuint _frameBuffer;              // The framebuffer Object
  
  GLuint _program;                  // The shader program used to render our texture into the FBO
  GLint _uniforms[NUM_UNIFORMS];    // List of uniforms

  
}

/**
 * Create the singleton
 */
+ (id) shared
{
	static dispatch_once_t predicate;
	static FBOPlugin * instance = nil;
	dispatch_once(&predicate, ^{instance = [[self alloc] init];});
	return instance;
}

/**
 * Call initializeTexture with a native texture ID to initialize the 
 * FBO and attach the nuity texture to it as a render target
 */
- (void) initializeTexture:(int)texture
{
  _unityTexture = texture;
  
  GLESAssert();
  //Save the current state
  GLint previousFBO, previousRenderBuffer, previous_program;
  glGetIntegerv(GL_FRAMEBUFFER_BINDING, &previousFBO);
  glGetIntegerv(GL_RENDERBUFFER_BINDING, &previousRenderBuffer);
  glGetIntegerv(GL_CURRENT_PROGRAM, &previous_program);
  
  //create the FBO
  if ([self createFBO])
  {
    //Render the source image into the FBO and update our Unity texture.
    [self updateTexture:0.0f];
  }
  else
  {
    NSLog(@"FBO not created");
    GLESAssert();
  }
  
  //Restore the state
  glBindFramebuffer(GL_FRAMEBUFFER, previousFBO);
  glBindRenderbuffer(GL_RENDERBUFFER, previousRenderBuffer);
  glUseProgram(previous_program);
}


/**
 * updateTexture updates the source image and is associated texture 
 * based on the float passed to it.
 * It then renders this to the FBO.
 * As the Unity texture is attached to the FBO as an output the rasterized 
 * result from the FBO is written in to it.
 */
- (void) updateTexture:(float)value
{
  GLESAssert();
  
  //Save current state
  GLint previousFBO, previousRenderBuffer, previous_program;
  glGetIntegerv(GL_FRAMEBUFFER_BINDING, &previousFBO);
  glGetIntegerv(GL_RENDERBUFFER_BINDING, &previousRenderBuffer);
  glGetIntegerv(GL_CURRENT_PROGRAM, &previous_program);
  
  //Need to set up the FBO first
  if (!_frameBuffer) {
    NSLog(@"ERROR FBO not created");
    return;
  }
  
  //Generate a new image and update source texture
  [self generateImage:value];
  
  //Set up our FBO
  glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
  GLESAssert();
  glViewport(0, 0, TEXTURE_WIDTH, TEXTURE_HEIGHT);
  GLESAssert();
  glDisable(GL_BLEND);
  glDisable(GL_DEPTH_TEST);
  glDepthMask(GL_FALSE);
  glDisable(GL_CULL_FACE);
  glBindBuffer(GL_ARRAY_BUFFER, 0);
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
  glPolygonOffset(0.0f, 0.0f);
  glDisable(GL_POLYGON_OFFSET_FILL);
  GLESAssert();
  
  //Load the shaders if we have not done so
  if (_program == 0)
  {
    if(![self loadShaders]) {
      NSLog(@"Failed to load shaders!");
    }
  }
  
  //Set up the program
  GLES_CHK( glUseProgram(_program) );
  GLES_CHK( glUniform1i(_uniforms[UNIFORM_TEXTURE], 0) );
  
  //clear the scene
  GLES_CHK( glClearColor(0.0f, 0.0f, 0.0f, 1.0f) );
  glClear(GL_COLOR_BUFFER_BIT);
  
  //Bind out source texture
  GLES_CHK( glActiveTexture(GL_TEXTURE0) );
  GLES_CHK( glBindTexture(GL_TEXTURE_2D, _sourceTexture) );
  
  //Our object to render
  static const GLfloat imageVertices[] = {
    -1.0f, -1.0f,
    1.0f, -1.0f,
    -1.0f,  1.0f,
    1.0f,  1.0f,
  };
  
  //The object's texture coordinates
  static const GLfloat textureCoordinates[] = {
    0.0f, 1.0f,
    1.0f, 1.0f,
    0.0f,  0.0f,
    1.0f,  0.0f,
  };
  
  // Update attribute values.
	GLES_CHK( glEnableVertexAttribArray(ATTRIB_VERTEX) );
	GLES_CHK( glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, 0, 0, imageVertices) );
	GLES_CHK( glEnableVertexAttribArray(ATTRIB_TEXTUREPOSITON) );
	GLES_CHK( glVertexAttribPointer(ATTRIB_TEXTUREPOSITON, 2, GL_FLOAT, 0, 0, textureCoordinates) );
  
  //Draw the quad
	GLES_CHK( glDrawArrays(GL_TRIANGLE_STRIP, 0, 4) );
  
  //Reset everything
  GLES_CHK( glActiveTexture(GL_TEXTURE0) );
  GLES_CHK( glBindTexture(GL_TEXTURE_2D, 0) );
  GLES_CHK( glActiveTexture(GL_TEXTURE1) );
  GLES_CHK( glBindTexture(GL_TEXTURE_2D, 0) );
  GLES_CHK( glBindVertexArrayOES(0) );
  GLES_CHK( glDisableVertexAttribArray(ATTRIB_VERTEX) );
  GLES_CHK( glDisableVertexAttribArray(ATTRIB_TEXTUREPOSITON) );
  
  //Restore ttate
  glBindFramebuffer(GL_FRAMEBUFFER, previousFBO);
  GLESAssert();
  glBindRenderbuffer(GL_RENDERBUFFER, previousRenderBuffer);
  GLESAssert();
  glUseProgram(previous_program);
  GLESAssert();
}

/**
 * Create the Framebuffer Object.
 * If the FBO already exists, then the unity texture is reattached. 
 * This allows you to change the texture target if needed.
 */
- (BOOL) createFBO
{
  if (_unityTexture <= 0) {
    NSLog(@"Unity Texture not set");
    return NO;
  }
  
  //Create a new framebuffer if needed
  if(!_frameBuffer)
  {
    glGenFramebuffers(1, &_frameBuffer);
    GLESAssert();
  }
  
  //bind FBO
  glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
  GLESAssert();
  
  //bind the output texture and attach it
  glBindTexture(GL_TEXTURE_2D, _unityTexture);
  GLESAssert();
  glTexImage2D(GL_TEXTURE_2D,
               0,
               GL_RGBA,
               TEXTURE_WIDTH,
               TEXTURE_HEIGHT,
               0,
               GL_RGBA,
               GL_UNSIGNED_BYTE,
               0);
  GLESAssert();
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  GLESAssert();
  
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, 0, 0);
  GLESAssert();
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _unityTexture, 0);
  GLESAssert();
  
  //Did it work?
  GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
  
  if(status != GL_FRAMEBUFFER_COMPLETE)
  {
    NSLog(@"ERROR: UNITY PLUGIN CANNOT MAKE VALID FBO ATTACHMENT FROM UNITY TEXTURE ID");
    return NO;
  }
  
  GLESAssert();
  
  return YES;
}

/**
 * Destroy the FBO.
 * We don't actually call this in this example, as we never need to. 
 * But this is how to do it.
 */
- (void) teardownFBO
{
  if (_frameBuffer != 0) {
    glDeleteFramebuffers(1, &_frameBuffer);
    _frameBuffer = 0;
  }
}

/**
 * This silly function creates an image based on the 0-1 float value passed to it.
 * It then uploads it to the GPU as a texture.
 * This texture will be later rendered to the FBO
 */
- (void) generateImage:(float)value
{
  if (value < 0.0f) value = 0.0f;
  if (value > 1.0f) value = 1.0f;
  
  GLubyte image[TEXTURE_HEIGHT][TEXTURE_WIDTH][3];
  
  for (int row = 0; row < TEXTURE_HEIGHT; row++)
  {
    for (int col = 0; col < TEXTURE_WIDTH; col++)
    {
      GLubyte r, g, b;
      //Top
      if (row < TEXTURE_HEIGHT/2)
      {
        //Left
        if (col < TEXTURE_WIDTH/2) {
          r = (GLubyte)(MAX(value, 0.1f)* 255.0f);
          g = b = 0;
        }
        //Right
        else {
          g = (GLubyte)(MAX((1.0f - value), 0.2f) * 255.0f);
          r = b = 0;
        }
      }
      //Bottom
      else
      {
        //Left
        if (col < TEXTURE_WIDTH/2) {
          b = (GLubyte)(0.5f * value * 255.0f) + 50;
          r = g = 0;
        }
        //Right
        else {
          r = g = b = (GLubyte)(value * 255.0f);
        }
      }
      
      //Set the pixels
      image[row][col][0]  = r;
      image[row][col][1]  = g;
      image[row][col][2]  = b;
    }
  }
  
  //Create the texture if it does not exist yet
  if (_sourceTexture <= 0)
  {
    glGenTextures(1, &_sourceTexture);
    glBindTexture(GL_TEXTURE_2D, _sourceTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  }
  else {
    // Otherwise just bind it
    glBindTexture(GL_TEXTURE_2D, _sourceTexture);
  }
  
  //Upload the image data
  glTexImage2D(GL_TEXTURE_2D,
               0,
               GL_RGB,
               TEXTURE_WIDTH,
               TEXTURE_HEIGHT,
               0,
               GL_RGB,
               GL_UNSIGNED_BYTE,
               image);
}


#pragma mark -  OpenGL ES 2 shader compilation
/*
 Everything below was just ripped from an Apple example project.
 This is boilerplate stuff. It can be done better and more flexibly,
 but it serves its purpose for this demo.
 
 The key thing to note here is that the shaders are stored as embedded strings.
 You could pass the strings in yourself or load up files from the Resources folder.
 */

/**
 * Load up the basic passthrough shaders
 */
- (BOOL)loadShaders
{
  glUseProgram(0);
  
  //shaders as embedded strings as we are making a library
  const GLchar vShaderStr[] =
  "attribute vec4 position;                             \n"
  "attribute mediump vec4 textureCoordinate;            \n"
  "varying mediump vec2 coordinate;                     \n"
  "void main()                                          \n"
  "{                                                    \n"
  "  gl_Position = position;                            \n"
  "  coordinate = textureCoordinate.xy;                 \n"
  "}";
  
  const GLchar fShaderStr[] =
  "varying highp vec2 coordinate;                       \n"
  "uniform sampler2D texture;                           \n"
  "void main()                                          \n"
  "{                                                    \n"
  "  gl_FragColor = texture2D(texture, coordinate);     \n"
  "}";
  
  GLuint vertShader, fragShader;
  
  // Create shader program.
  _program = glCreateProgram();
  
  // Create and compile vertex shader.
  if (![self compileShader:&vertShader type:GL_VERTEX_SHADER src:vShaderStr]) {
    NSLog(@"Failed to compile vertex shader");
    return NO;
  }
  
  // Create and compile fragment shader.
  if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER src:fShaderStr]) {
    NSLog(@"Failed to compile fragment shader");
    return NO;
  }
  
  // Attach vertex shader to _program.
  glAttachShader(_program, vertShader);
  
  // Attach fragment shader to _program.
  glAttachShader(_program, fragShader);
  
  
  // Bind attribute locations.
  // This needs to be done prior to linking.
  glBindAttribLocation(_program, ATTRIB_VERTEX, "position");
  glBindAttribLocation(_program, ATTRIB_TEXTUREPOSITON, "textureCoordinate");
  
  // Link program.
  if (![self linkProgram:_program]) {
    NSLog(@"Failed to link _program: %d", _program);
    
    if (vertShader) {
      glDeleteShader(vertShader);
      vertShader = 0;
    }
    if (fragShader) {
      glDeleteShader(fragShader);
      fragShader = 0;
    }
    if (_program) {
      glDeleteProgram(_program);
      _program = 0;
    }
    
    return NO;
  }
  
  // Get uniform locations.
  _uniforms[UNIFORM_TEXTURE]  = glGetUniformLocation(_program, "texture");
  
  
  // Release vertex and fragment shaders.
  if (vertShader) {
    glDetachShader(_program, vertShader);
    glDeleteShader(vertShader);
  }
  if (fragShader) {
    glDetachShader(_program, fragShader);
    glDeleteShader(fragShader);
  }
  
  return YES;
}

/**
 * Compile a shader
 */
- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type src:(const GLchar *)source
{
  GLint status;
  if (!source) {
    NSLog(@"Failed to load shader");
    return NO;
  }
  
  *shader = glCreateShader(type);
  glShaderSource(*shader, 1, &source, NULL);
  glCompileShader(*shader);
  
#if defined(DEBUG)
  GLint logLength;
  glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
  if (logLength > 0) {
    GLchar *log = (GLchar *)malloc(logLength);
    glGetShaderInfoLog(*shader, logLength, &logLength, log);
    NSLog(@"Shader compile log:\n%s", log);
    free(log);
  }
#endif
  
  glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
  if (status == 0) {
    glDeleteShader(*shader);
    return NO;
  }
  
  return YES;
}

/**
 * Link the program
 */
- (BOOL)linkProgram:(GLuint)prog
{
  GLint status;
  glLinkProgram(prog);
  
#if defined(DEBUG)
  GLint logLength;
  glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
  if (logLength > 0) {
    GLchar *log = (GLchar *)malloc(logLength);
    glGetProgramInfoLog(prog, logLength, &logLength, log);
    NSLog(@"Program link log:\n%s", log);
    free(log);
  }
#endif
  
  glGetProgramiv(prog, GL_LINK_STATUS, &status);
  if (status == 0) {
    return NO;
  }
  
  return YES;
}

/**
 * Check that the program is valid.
 */
- (BOOL)validateProgram:(GLuint)prog
{
  GLint logLength, status;
  
  glValidateProgram(prog);
  glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
  if (logLength > 0) {
    GLchar *log = (GLchar *)malloc(logLength);
    glGetProgramInfoLog(prog, logLength, &logLength, log);
    NSLog(@"Program validate log:\n%s", log);
    free(log);
  }
  
  glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
  if (status == 0) {
    return NO;
  }
  
  return YES;
}


@end
