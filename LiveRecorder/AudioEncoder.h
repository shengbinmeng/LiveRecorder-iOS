//
//  AudioEncoder.h
//  LiveRecorder
//
//  Created by Shengbin Meng on 9/15/15.
//  Copyright (c) 2015 Shengbin Meng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "StreamOutput.h"

@interface AudioEncoder : NSObject

@property StreamOutput *output;

@property int sampleRate;
@property int channelCount;
@property int bitrate;

- (void) setSampleRate:(int)sampleRate channelCount:(int)channelCount bitrate:(int)bitrate;
- (int) open;
- (int) encode:(CMSampleBufferRef)sampleBuffer;
- (int) close;

@end
