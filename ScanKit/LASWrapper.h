//
//  LASWrapper.h
//  ScanKit
//
//  Created by Kenneth Schröder on 20.09.21.
//

#ifndef LASWrapper_h
#define LASWrapper_h

#import <Foundation/Foundation.h>
#import "ShaderTypes.h"

// This is a wrapper Objective-C++ class around the C++ class
@interface LASwriter_oc : NSObject

-(void)write_lasFile:(ParticleUniforms[])points ofSize:(int)length toFileNamed:(const char *)name;

@end

#endif /* LASWrapper_h */
