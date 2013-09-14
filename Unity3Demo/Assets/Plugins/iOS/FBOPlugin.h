//
//  FBOPlugin.h
//  FBOPlugin
//
//  Created by Robert Castle on 13/09/2013.
//  Copyright (c) 2013 Egomotion Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

/*
 * Interop functions. C# calls these.
 */
extern "C"
{
  void InitializeTexture(int textureID);
  void UpdateTexture(float value);
}

/*
 * The main class that manages the FBO
 */
@interface FBOPlugin : NSObject

+ (id) shared;

- (void) initializeTexture:(int)texture;
- (void) updateTexture:(float)value;
@end
