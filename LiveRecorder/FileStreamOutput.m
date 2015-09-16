//
//  FileStreamOutput.m
//  LiveRecorder
//
//  Created by Shengbin Meng on 9/15/15.
//  Copyright (c) 2015 Shengbin Meng. All rights reserved.
//

#import "FileStreamOutput.h"

@implementation FileStreamOutput
{
    NSFileHandle *mVideoFileHandle;
}

- (int) open:(NSString*) address{
    [super open:address];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *videoFile = [NSString stringWithFormat:@"%@/%@/video.avc", documentsDirectory, address];
    videoFile = [videoFile stringByStandardizingPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:videoFile error:nil];
    [fileManager createFileAtPath:videoFile contents:nil attributes:nil];
    mVideoFileHandle = [NSFileHandle fileHandleForWritingAtPath:videoFile];
    return 0;
}

- (int) didReceiveEncodedAudio:(CMSampleBufferRef) sampleBuffer {
    [super didReceiveEncodedAudio:sampleBuffer];
    return 0;
}

- (int) didReceiveEncodedVideo:(CMSampleBufferRef) sampleBuffer {
    [super didReceiveEncodedVideo:sampleBuffer];
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
                // Found pps.
                const char bytes[] = "\x00\x00\x00\x01";
                size_t length = sizeof(bytes) - 1; //string literals have implicit trailing '\0'
                NSData *prefix = [NSData dataWithBytes:bytes length:length];
                NSData *sps = [NSData dataWithBytes:spsContent length:spsSize];
                NSData *pps = [NSData dataWithBytes:ppsContent length:ppsSize];
                
                [mVideoFileHandle writeData:prefix];
                [mVideoFileHandle writeData:sps];
                [mVideoFileHandle writeData:prefix];
                [mVideoFileHandle writeData:pps];
            }
        }
    }
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    NSLog(@"Sample buffer's pts: %lf (%lld)", (double)pts.value / pts.timescale, pts.value);
    size_t lengthAtOffset, totalLength, offset = 0;
    char *dataPointer;
    OSStatus status = CMBlockBufferGetDataPointer(dataBuffer, offset, &lengthAtOffset, &totalLength, &dataPointer);
    if (status == noErr) {
        NSLog(@"Data buffer's length at offset: %zu, total length: %zu", lengthAtOffset, totalLength);
        static const int AVCCHeaderLength = 4;
        size_t dataOffset = 0;
        while (dataOffset + AVCCHeaderLength < totalLength) {
            // Read the NAL unit length.
            uint32_t nalUnitLength = 0;
            memcpy(&nalUnitLength, dataPointer + dataOffset, AVCCHeaderLength);
            
            // Convert the length value from Big-endian to Little-endian.
            nalUnitLength = CFSwapInt32BigToHost(nalUnitLength);
            
            // Write this NAL unit (including the start code prefix) to file.
            const char bytes[] = "\x00\x00\x00\x01";
            size_t length = sizeof(bytes) - 1; //string literals have implicit trailing '\0'
            NSData *prefix = [NSData dataWithBytes:bytes length:length];
            NSData* nalu = [NSData dataWithBytes:(dataPointer + dataOffset + AVCCHeaderLength) length:nalUnitLength];
            [mVideoFileHandle writeData:prefix];
            [mVideoFileHandle writeData:nalu];
            
            // Move to the next NAL unit in the block buffer.
            dataOffset += AVCCHeaderLength + nalUnitLength;
        }
    }
    
    return 0;
}

- (int) close {
    [super close];
    [mVideoFileHandle closeFile];
    return 0;
}

@end
