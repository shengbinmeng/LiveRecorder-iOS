//
//  VideoEncoder.h
//  LiveRecorder
//
//  Created by Shengbin Meng on 9/14/15.
//  Copyright (c) 2015 Shengbin Meng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "StreamOutput.h"
@import AVFoundation;

@interface VideoEncoder : NSObject

@property StreamOutput *output;
@property int width;
@property int height;
@property int frameRate;
@property int bitrate;

- (void) setWidth:(int)width height:(int)height frameRate:(int)frameRate bitrate:(int)bitrate;
- (int) open;
- (int) encode:(CMSampleBufferRef)sampleBuffer;
- (int) close;

@end
