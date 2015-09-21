//
//  HardwareAudioEncoder.m
//  LiveRecorder
//
//  Created by Shengbin Meng on 9/17/15.
//  Copyright (c) 2015 Shengbin Meng. All rights reserved.
//

#import "HardwareAudioEncoder.h"

@implementation HardwareAudioEncoder
{
    AudioConverterRef _audioConverter;
    char *_aacBuffer;
    NSUInteger _aacBufferSize;
    char *_pcmBuffer;
    size_t _pcmBufferSize;
    AudioBufferList _outAudioBufferList;
    size_t _bytesPerFrame;
}

- (int) open {
    [super open];
    _aacBufferSize = 1024;
    _aacBuffer = malloc(_aacBufferSize * sizeof(uint8_t));
    memset(_aacBuffer, 0, _aacBufferSize);
    
    return 0;
}

- (void) setupAACEncoderFromSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    // Get the input audio stream description for the converter.
    CMAudioFormatDescriptionRef audioFormatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
    AudioStreamBasicDescription inAudioStreamBasicDescription = *CMAudioFormatDescriptionGetStreamBasicDescription(audioFormatDescription);
    
    // Construct the output audio stream description for the converter.
    AudioStreamBasicDescription outAudioStreamBasicDescription = {0}; // Always initialize the struct to 0.
    
    // The number of frames per second of the data in the stream, when the stream is played at normal speed. For compressed formats, this field indicates the number of frames per second of equivalent decompressed data. The mSampleRate field must be nonzero, except when this structure is used in a listing of supported formats (see “kAudioStreamAnyRate”).
    if (self.sampleRate != 0) {
        outAudioStreamBasicDescription.mSampleRate = self.sampleRate;
    } else {
        outAudioStreamBasicDescription.mSampleRate = inAudioStreamBasicDescription.mSampleRate;
    }
    
    outAudioStreamBasicDescription.mFormatID = kAudioFormatMPEG4AAC;
    outAudioStreamBasicDescription.mFormatFlags = kMPEG4Object_AAC_Main; // Format-specific flags to specify details of the format. Set to 0 to indicate no format flags. See “Audio Data Format Identifiers” for the flags that apply to each format.
    outAudioStreamBasicDescription.mBytesPerPacket = 0; // The number of bytes in a packet of audio data. To indicate variable packet size, set this field to 0. For a format that uses variable packet size, specify the size of each packet using an AudioStreamPacketDescription structure.
    
    // Calculate how many frames are in a packet. (One input packet is converted to one output packet.)
    CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t bytesPerPacket;
    CMBlockBufferGetDataPointer(blockBuffer, 0, NULL, &bytesPerPacket, NULL);
    UInt32 framesPerPacket = (UInt32)bytesPerPacket / inAudioStreamBasicDescription.mBytesPerFrame;
    
    outAudioStreamBasicDescription.mFramesPerPacket = framesPerPacket; // The number of frames in a packet of audio data. For uncompressed audio, the value is 1 (for PCM, a packet contains one frame; for audio, a frame is just a sample, so frameRate is sampleRate). For variable bit-rate formats, the value is a larger fixed number, such as 1024 for AAC. For formats with a variable number of frames per packet, such as Ogg Vorbis, set this field to 0.
    outAudioStreamBasicDescription.mBytesPerFrame = 0; // The number of bytes from the start of one frame to the start of the next frame in an audio buffer. Set this field to 0 for compressed formats.
    
    // The number of channels in each frame of audio data. This value must be nonzero.
    if (self.channelCount != 0) {
        outAudioStreamBasicDescription.mChannelsPerFrame = self.channelCount;
    } else {
        outAudioStreamBasicDescription.mChannelsPerFrame = inAudioStreamBasicDescription.mChannelsPerFrame;
    }
    
    outAudioStreamBasicDescription.mBitsPerChannel = 0; // Set this field to 0 for compressed formats.
    outAudioStreamBasicDescription.mReserved = 0; // Pads the structure out to force an even 8-byte alignment. Must be set to 0.
    
    AudioClassDescription description;
    [self getAudioClassDescription:&description withType:kAudioFormatMPEG4AAC fromManufacturer:kAppleSoftwareAudioCodecManufacturer];
    
    OSStatus status = AudioConverterNewSpecific(&inAudioStreamBasicDescription, &outAudioStreamBasicDescription, 1, &description, &_audioConverter);
    if (status != noErr) {
        NSLog(@"Setup converter failed with status: %d", (int)status);
    }
    
    UInt32 bitrate = 64000;
    if (self.bitrate != 0) {
        bitrate = (UInt32)self.bitrate;
    }
    status = AudioConverterSetProperty(_audioConverter, kAudioConverterEncodeBitRate, sizeof(bitrate), &bitrate);
    if (status != noErr) {
        NSLog(@"AudioConverterSetProperty failed with status: %d", (int)status);
    }
    
    _outAudioBufferList.mNumberBuffers = 1;
    _outAudioBufferList.mBuffers[0].mNumberChannels = outAudioStreamBasicDescription.mChannelsPerFrame;
    memset(_aacBuffer, 0, _aacBufferSize);
    _outAudioBufferList.mBuffers[0].mDataByteSize = (UInt32)_aacBufferSize;
    _outAudioBufferList.mBuffers[0].mData = _aacBuffer;
    _bytesPerFrame = inAudioStreamBasicDescription.mBytesPerFrame;
}

- (int) getAudioClassDescription:(AudioClassDescription*)desc withType:(UInt32)type fromManufacturer:(UInt32) manufacturer {
    OSStatus status;
    
    UInt32 encoderSpecifier = type;
    UInt32 size;
    status = AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders, sizeof(encoderSpecifier), &encoderSpecifier, &size);
    if (status != noErr) {
        NSLog(@"Get audio format propery info failed with status: %d", (int)status);
        return -1;
    }
    
    UInt32 count = size / sizeof(AudioClassDescription);
    AudioClassDescription descriptions[count];
    status = AudioFormatGetProperty(kAudioFormatProperty_Encoders, sizeof(encoderSpecifier), &encoderSpecifier, &size, descriptions);
    if (status != noErr) {
        NSLog(@"Get audio format propery failed with status: %d", (int)status);
        return -1;
    }
    
    for (int i = 0; i < count; i++) {
        if ((type == descriptions[i].mSubType) && (manufacturer == descriptions[i].mManufacturer)) {
            memcpy(desc, &(descriptions[i]), sizeof(*desc));
            break;
        }
    }
    
    return 0;
}

static OSStatus inputDataProc(AudioConverterRef inAudioConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription **outDataPacketDescription, void *inUserData) {
    HardwareAudioEncoder *encoder = (__bridge HardwareAudioEncoder*)(inUserData);
    
    UInt32 framesPerPacket = 1; // This is true for input PCM data.

    UInt32 requestedFrames = (*ioNumberDataPackets) * framesPerPacket;
    size_t copiedFrames = [encoder copyPcmFramesIntoBuffer:ioData];
    NSLog(@"Number of frames requested: %d, copied: %zu", (unsigned int)requestedFrames, copiedFrames);
    if (copiedFrames < requestedFrames) {
        NSLog(@"PCM buffer isn't full enough");
        *ioNumberDataPackets = 0;
        return -1;
    }
    *ioNumberDataPackets = (UInt32)copiedFrames / framesPerPacket;
    NSLog(@"Copied %zu frames into ioData", copiedFrames);
    return noErr;
}

- (size_t) copyPcmFramesIntoBuffer:(AudioBufferList*)ioData {
    size_t numberFrames = _pcmBufferSize / _bytesPerFrame;
    ioData->mBuffers[0].mData = _pcmBuffer;
    ioData->mBuffers[0].mDataByteSize =(UInt32) _pcmBufferSize;
    _pcmBuffer = NULL;
    _pcmBufferSize = 0;
    return numberFrames;
}

- (int) encode:(CMSampleBufferRef)sampleBuffer {
    [super encode:sampleBuffer];
    
    CFRetain(sampleBuffer);
    if (!_audioConverter) {
        [self setupAACEncoderFromSampleBuffer:sampleBuffer];
    }
    
    CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    CFRetain(blockBuffer);
    CMBlockBufferGetDataPointer(blockBuffer, 0, NULL, &_pcmBufferSize, &_pcmBuffer);
    
    memset(_aacBuffer, 0, _aacBufferSize);
    _outAudioBufferList.mBuffers[0].mDataByteSize = (UInt32)_aacBufferSize;
    _outAudioBufferList.mBuffers[0].mData = _aacBuffer;
    
    AudioStreamPacketDescription *outPacketDescription = NULL;
    UInt32 ioOutputDataPacketSize = 1;
    OSStatus status = AudioConverterFillComplexBuffer(_audioConverter, inputDataProc, (__bridge void *)(self), &ioOutputDataPacketSize, &_outAudioBufferList, outPacketDescription);
    
    // We provide output data packet size of 1, so its actual size should still be 1.
    NSLog(@"ioOutputDataPacketSize: %d", (unsigned int)ioOutputDataPacketSize);
    
    if (status == noErr) {
        NSData *rawAAC = [NSData dataWithBytes:_outAudioBufferList.mBuffers[0].mData length:_outAudioBufferList.mBuffers[0].mDataByteSize];
        CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        [self.output didReceiveEncodedAudio:rawAAC presentationTime:pts];
    } else {
        NSLog(@"AudioConverterFillComplexBuffer failed with status: %d", (int)status);
    }
    
    CFRelease(sampleBuffer);
    CFRelease(blockBuffer);
    
    return 0;
}

@end
