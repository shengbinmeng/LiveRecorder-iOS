//
//  CoreRecorder.h
//  LiveRecorder
//
//  Created by Shengbin *eng on 9/14/15.
//  Copyright (c) 2015 Shengbin *eng. All rights reserved.
//

#import <Foundation/Foundation.h>
@import AVFoundation;
#import "AudioEncoder.h"
#import "VideoEncoder.h"
#import "StreamOutput.h"

@interface CoreRecorder : NSObject

@property AudioEncoder *audioEncoder;
@property VideoEncoder *videoEncoder;
@property StreamOutput *output;
@property int sampleRate;
@property int channelCount;
@property int audioBitrate;
@property int width;
@property int height;
@property int frameRate;
@property int videoBitrate;
@property NSString *outputAddress;

- (void) setSampleRate:(int)sampleRate channelCount:(int)channelCount audioBitrate:(int)audioBitrate width:(int)width height:(int)height frameRate:(int)frameRate videoBitrate:(int)videoBitrate outputAddress:(NSString*) address;
- (int) start;
- (int) didReceiveAudioSamples:(CMSampleBufferRef)sampleBuffer;
- (int) didReceiveVideoSamples:(CMSampleBufferRef)sampleBuffer;
- (int) stop;

@end
