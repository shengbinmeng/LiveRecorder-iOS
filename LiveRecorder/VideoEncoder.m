//
//  VideoEncoder.m
//  LiveRecorder
//
//  Created by Shengbin Meng on 9/14/15.
//  Copyright (c) 2015 Shengbin Meng. All rights reserved.
//

#import "VideoEncoder.h"

@implementation VideoEncoder

- (id) init {
    self = [super init];
    if (self) {
        self.width = 640;
        self.height = 480;
        self.frameRate = 30;
        self.bitrate = 200000;
    }
    return self;
}

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

- (int) encode {
    NSLog(@"VideoEncoder encode");
    return 0;
}


- (int) close {
    NSLog(@"VideoEncoder close");
    return 0;
}

@end
