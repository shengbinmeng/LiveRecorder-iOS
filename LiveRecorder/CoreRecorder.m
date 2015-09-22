//
//  CoreRecorder.m
//  LiveRecorder
//
//  Created by Shengbin Meng on 9/14/15.
//  Copyright (c) 2015 Shengbin Meng. All rights reserved.
//

@import CoreImage;
#import "CoreRecorder.h"
#import "HardwareVideoEncoder.h"
#import "HardwareAudioEncoder.h"
#import "FileStreamOutput.h"
#import "LiveStreamOutput.h"

@implementation CoreRecorder

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
    if (self.width == 0 || self.height == 0 || self.outputAddress == nil) {
        NSLog(@"Must at least set width, height and output address before start recorder");
        return -1;
    }
    int ret = 0;
    self.output = [[LiveStreamOutput alloc] init];
    [self.output open:self.outputAddress];
    
    self.audioEncoder = [[HardwareAudioEncoder alloc] init];
    self.audioEncoder.output = self.output;
    [self.audioEncoder setSampleRate:self.sampleRate channelCount:self.channelCount bitrate:self.audioBitrate];
    
    self.videoEncoder = [[HardwareVideoEncoder alloc] init];
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
    [self.audioEncoder encode:sampleBuffer];
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
    [self.videoEncoder encode:sampleBuffer];
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
