//
//  HardwareVideoEncoder.m
//  LiveRecorder
//
//  Created by Shengbin Meng on 9/15/15.
//  Copyright (c) 2015 Shengbin Meng. All rights reserved.
//

#import "HardwareVideoEncoder.h"
@import VideoToolbox;

@implementation HardwareVideoEncoder
{
    VTCompressionSessionRef _encodingSession;
}

void didCompressH264(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer) {
    if (status != 0) {
        NSLog(@"didCompressH264 error: %d", status);
        return;
    }
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        NSLog(@"didCompressH264 data is not ready");
        return;
    }
    
    HardwareVideoEncoder* encoder = (__bridge HardwareVideoEncoder*)outputCallbackRefCon;
    [encoder.output didReceiveEncodedVideo:sampleBuffer];
}

- (int) open {
    [super open];
    // Create the compression session.
    OSStatus status = VTCompressionSessionCreate(NULL, self.width, self.height, kCMVideoCodecType_H264, NULL, NULL, NULL, didCompressH264, (__bridge void *)(self),  &_encodingSession);
    if (status != 0) {
        NSLog(@"Unable to create a H264 compression session");
        return -1;
    }
    
    // Set the properties.
    int keyFrameInterval = 240;
    CFNumberRef keyFrameIntervalRef = CFNumberCreate(NULL, kCFNumberSInt32Type, &keyFrameInterval);
    VTSessionSetProperty(_encodingSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, keyFrameIntervalRef);
    VTSessionSetProperty(_encodingSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    VTSessionSetProperty(_encodingSession, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
    VTSessionSetProperty(_encodingSession, kVTCompressionPropertyKey_ProfileLevel,kVTProfileLevel_H264_High_AutoLevel);
    if (self.bitrate > 0) {
        int bitrate = self.bitrate;
        CFNumberRef bitrateRef = CFNumberCreate(NULL, kCFNumberSInt32Type, &bitrate);
        VTSessionSetProperty(_encodingSession, kVTCompressionPropertyKey_AverageBitRate, bitrateRef);
    }
    if (self.frameRate > 0) {
        int frameRate = self.frameRate;
        CFNumberRef frameRateRef = CFNumberCreate(NULL, kCFNumberSInt32Type, &frameRate);
        VTSessionSetProperty(_encodingSession, kVTCompressionPropertyKey_ExpectedFrameRate, frameRateRef);
    }
    
    // Tell the encoder to start encoding.
    VTCompressionSessionPrepareToEncodeFrames(_encodingSession);
    return 0;
}

- (int) encode:(CMSampleBufferRef)sampleBuffer {
    [super encode:sampleBuffer];
    CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
    CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    NSLog(@"Encode a frame, pts: %lf (%lld)", (double)pts.value / pts.timescale, pts.value);
    VTEncodeInfoFlags flags;
    OSStatus status = VTCompressionSessionEncodeFrame(_encodingSession, imageBuffer, pts, kCMTimeInvalid, NULL, NULL, &flags);
    if (status != noErr) {
        NSLog(@"VTCompressionSessionEncodeFrame failed with statuc %d", (int)status);
        return -1;
    }

    return 0;
}

- (int) close {
    [super close];
    VTCompressionSessionCompleteFrames(_encodingSession, kCMTimeInvalid);
    VTCompressionSessionInvalidate(_encodingSession);
    CFRelease(_encodingSession);
    return 0;
}

@end
