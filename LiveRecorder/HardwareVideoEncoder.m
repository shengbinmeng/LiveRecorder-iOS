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
        NSLog(@"didCompressH264 error: %d", (int)status);
        return;
    }
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        NSLog(@"didCompressH264 data is not ready");
        return;
    }
    
    // H.264 bitstream from CMSampleBuffer is in AVCC format. We will transform it to video data of Annex B format before output.
    NSMutableData *videoData = [NSMutableData dataWithLength:0];
    
    // Check if we have got a key frame.
    CFArrayRef attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true);
    CFDictionaryRef attachments = CFArrayGetValueAtIndex(attachmentsArray, 0);
    bool isKeyframe = !CFDictionaryContainsKey(attachments, kCMSampleAttachmentKey_NotSync);
    if (isKeyframe) {
        NSLog(@"This is a key frame");
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        size_t spsSize, spsCount;
        const uint8_t *spsContent;
        OSStatus status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &spsContent, &spsSize, &spsCount, 0);
        if (status == noErr) {
            // Found sps and now check for pps.
            size_t ppsSize, ppsCount;
            const uint8_t *ppsContent;
            OSStatus status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &ppsContent, &ppsSize, &ppsCount, 0);
            if (status == noErr) {
                // Found pps. Add start code prefix and construct data of Annex B format.
                const char startCode[] = "\x00\x00\x00\x01";
                size_t startCodeLength = sizeof(startCode) - 1; //string literals have implicit trailing '\0'
                NSData *prefix = [NSData dataWithBytes:startCode length:startCodeLength];
                NSData *sps = [NSData dataWithBytes:spsContent length:spsSize];
                NSData *pps = [NSData dataWithBytes:ppsContent length:ppsSize];
                [videoData appendData:prefix];
                [videoData appendData:sps];
                [videoData appendData:prefix];
                [videoData appendData:pps];
                NSLog(@"Found sps and pps, length %lu and %lu", (unsigned long)sps.length, (unsigned long)pps.length);
            }
        }
    }
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t lengthAtOffset, totalLength, offset = 0;
    char *dataPointer;
    status = CMBlockBufferGetDataPointer(dataBuffer, offset, &lengthAtOffset, &totalLength, &dataPointer);
    if (status == noErr) {
        static const int AVCCHeaderLength = 4;
        size_t dataOffset = 0;
        while (dataOffset + AVCCHeaderLength < totalLength) {
            // Read the NAL unit length.
            uint32_t nalUnitLength = 0;
            memcpy(&nalUnitLength, dataPointer + dataOffset, AVCCHeaderLength);
            
            // Convert the length value from Big-endian to the host's byte order (Little-endian perhaps).
            nalUnitLength = CFSwapInt32BigToHost(nalUnitLength);
            
            // Transform this NAL unit to Annex B format (replace the AVCC header with start code prefix).
            const char startCode[] = "\x00\x00\x00\x01";
            size_t startCodeLength = sizeof(startCode) - 1; //string literals have implicit trailing '\0'
            NSData *prefix = [NSData dataWithBytes:startCode length:startCodeLength];
            NSData* nalu = [NSData dataWithBytes:(dataPointer + dataOffset + AVCCHeaderLength) length:nalUnitLength];
            [videoData appendData:prefix];
            [videoData appendData:nalu];
            
            // Move to the next NAL unit in the block buffer.
            // Though most of time there is only one NAL unit in a buffer, i.e., this loop only executes once.
            dataOffset += AVCCHeaderLength + nalUnitLength;
        }
    }
    
    if (videoData.length > 0) {
        CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        HardwareVideoEncoder* encoder = (__bridge HardwareVideoEncoder*)outputCallbackRefCon;
        [encoder.output didReceiveEncodedVideo:videoData presentationTime:pts isKeyFrame:isKeyframe];
    }
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
