//
//  CoreRecorder.m
//  LiveRecorder
//
//  Created by Shengbin Meng on 9/14/15.
//  Copyright (c) 2015 Shengbin Meng. All rights reserved.
//

#import "CoreRecorder.h"
@import CoreImage;

@implementation CoreRecorder

- (id) init {
    self = [super init];
    if (self) {
        // These are default values.
        self.sampleRate = 44100;
        self.channelCount = 2;
        self.audioBitrate = 20000;
        
        self.width = 640;
        self.height = 480;
        self.frameRate = 30;
        self.videoBitrate = 200000;
        
        self.outputAddress = @"/";
    }
    return self;
}

- (void) setSampleRate:(int)sampleRate channelCount:(int)channelCount audioBitrate:(int)audioBitrate width:(int)width height:(int)height frameRate:(int)frameRate videoBitrate:(int)videoBitrate outputAddress:(NSString*) address {
    self.sampleRate = sampleRate;
    self.channelCount = channelCount;
    self.audioBitrate = audioBitrate;
    self.width = width;
    self.height = height;
    self.frameRate = frameRate;
    self.videoBitrate = videoBitrate;
    self.outputAddress = address;
}

- (int) start {
    int ret = 0;
    self.output = [[StreamOutput alloc] init];
    [self.output open:self.outputAddress];
    
    self.audioEncoder = [[AudioEncoder alloc] init];
    self.audioEncoder.output = self.output;
    [self.audioEncoder setSampleRate:self.sampleRate channelCount:self.channelCount bitrate:self.audioBitrate];
    
    self.videoEncoder = [[VideoEncoder alloc] init];
    self.videoEncoder.output = self.output;
    [self.videoEncoder setWidth:self.width height:self.height frameRate:self.frameRate bitrate:self.videoBitrate];
    
    [self.audioEncoder open];
    [self.videoEncoder open];
    NSLog(@"Recorder started.");
    return ret;
}

- (int) didReceiveAudioSamples:(CMSampleBufferRef)sampleBuffer {
    int ret = 0;
    // Get the sample buffer's AudioStreamBasicDescription.
    CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
    const AudioStreamBasicDescription *audioFormat = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription);
    NSLog(@"Audio samples received, sample rate: %f", audioFormat->mSampleRate);
    if (audioFormat->mFormatID != kAudioFormatLinearPCM) {
        NSLog(@"Bad format");
        return -1;
    }
    [self.audioEncoder encode];
    return ret;
}

- (int) didReceiveVideoSamples:(CMSampleBufferRef)sampleBuffer {
    int ret = 0;
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
    CIImage *image = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer options:(__bridge NSDictionary *)attachments];
    NSLog(@"Video samples received, %@", image.description);
    if (attachments) {
        CFRelease(attachments);
    }
    [self.videoEncoder encode];
    return ret;
}

- (int) stop {
    int ret = 0;
    [self.audioEncoder close];
    [self.videoEncoder close];
    [self.output close];
    NSLog(@"Recorder stopped.");
    return ret;
}

@end
