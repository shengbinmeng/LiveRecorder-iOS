//
//  VideoEncoder.m
//  LiveRecorder
//
//  Created by Shengbin Meng on 9/14/15.
//  Copyright (c) 2015 Shengbin Meng. All rights reserved.
//

#import "VideoEncoder.h"

@implementation VideoEncoder

- (void) setWidth:(int)width height:(int)height frameRate:(int)frameRate bitrate:(int)bitrate {
    self.width = width;
    self.height = height;
    self.frameRate = frameRate;
    self.bitrate = bitrate;
}

- (int) open {
    NSLog(@"VideoEncoder open");
    return 0;
}

- (int) encode:(CMSampleBufferRef)sampleBuffer {
    NSLog(@"VideoEncoder encode");
    return 0;
}


- (int) close {
    NSLog(@"VideoEncoder close");
    return 0;
}

@end
