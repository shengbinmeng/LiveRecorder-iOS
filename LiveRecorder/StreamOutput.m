//
//  StreamOutput.m
//  LiveRecorder
//
//  Created by Shengbin Meng on 9/15/15.
//  Copyright (c) 2015 Shengbin Meng. All rights reserved.
//

#import "StreamOutput.h"

@implementation StreamOutput

- (int) open:(NSString*) address{
    NSLog(@"StreamOutput open: %@", address);
    return 0;
}

- (int) didReceiveEncodedAudio:(NSData*) audioData presentationTime:(CMTime)pts {
    NSLog(@"StreamOutput didReceiveEncodedAudio");
    return 0;
}

- (int) didReceiveEncodedVideo:(CMSampleBufferRef) sampleBuffer {
    NSLog(@"StreamOutput didReceiveEncodedVideo");
    return 0;
}

- (int) close {
    NSLog(@"StreamOutput close");
    return 0;
}

@end
