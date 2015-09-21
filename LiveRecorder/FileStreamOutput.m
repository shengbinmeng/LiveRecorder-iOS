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
    NSFileHandle *_videoFileHandle;
    NSFileHandle *_audioFileHandle;
}

- (int) open:(NSString*) address {
    [super open:address];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *videoFile = [NSString stringWithFormat:@"%@/%@/video.avc", documentsDirectory, address];
    videoFile = [videoFile stringByStandardizingPath];
    NSString *audioFile = [NSString stringWithFormat:@"%@/%@/audio.aac", documentsDirectory, address];
    audioFile = [audioFile stringByStandardizingPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:videoFile error:nil];
    [fileManager createFileAtPath:videoFile contents:nil attributes:nil];
    _videoFileHandle = [NSFileHandle fileHandleForWritingAtPath:videoFile];
    [fileManager removeItemAtPath:audioFile error:nil];
    [fileManager createFileAtPath:audioFile contents:nil attributes:nil];
    _audioFileHandle = [NSFileHandle fileHandleForWritingAtPath:audioFile];
    return 0;
}

- (NSData*) adtsHeaderForPacketLength:(NSUInteger)packetLength {
    int adtsLength = 7;
    char *packet = malloc(sizeof(char) * adtsLength);
    // Variables Recycled by addADTStoPacket
    int profile = 2;  //AAC LC
    int freqIdx = 4;  //44.1KHz
    int chanCfg = 1;  //MPEG-4 Audio Channel Configuration. 1 Channel front-center
    NSUInteger fullLength = adtsLength + packetLength;
    // fill in ADTS data
    packet[0] = (char)0xFF;	// 11111111  	= syncword
    packet[1] = (char)0xF9;	// 1111 1 00 1  = syncword MPEG-2 Layer CRC
    packet[2] = (char)(((profile-1)<<6) + (freqIdx<<2) +(chanCfg>>2));
    packet[3] = (char)(((chanCfg&3)<<6) + (fullLength>>11));
    packet[4] = (char)((fullLength&0x7FF) >> 3);
    packet[5] = (char)(((fullLength&7)<<5) + 0x1F);
    packet[6] = (char)0xFC;
    NSData *adtsHeader = [NSData dataWithBytesNoCopy:packet length:adtsLength freeWhenDone:YES];
    return adtsHeader;
}

- (int) didReceiveEncodedAudio:(NSData*) audioData presentationTime:(CMTime)pts {
    NSLog(@"Received encoded audio data, length: %lu, pts: %lf (%lld)", (unsigned long)audioData.length, (double)pts.value / pts.timescale, pts.value);
    // Add ADTS header to raw AAC audio data so the audio file written can be played.
    NSData *adtsHeader = [self adtsHeaderForPacketLength:audioData.length];
    NSMutableData *adtsAAC = [NSMutableData dataWithData:adtsHeader];
    [adtsAAC appendData:audioData];
    [_audioFileHandle writeData:adtsAAC];
    return 0;
}

- (int) didReceiveEncodedVideo:(NSData*) videoData presentationTime:(CMTime)pts isKeyFrame:(BOOL)keyFrame {
    NSLog(@"Received encoded video data, length: %lu, pts: %lf (%lld)", (unsigned long)videoData.length, (double)pts.value / pts.timescale, pts.value);
    [_videoFileHandle writeData:videoData];
    return 0;
}

- (int) close {
    [super close];
    [_videoFileHandle closeFile];
    [_audioFileHandle closeFile];
    return 0;
}

@end
