//
//  AudioEncoder.m
//  LiveRecorder
//
//  Created by Shengbin Meng on 9/15/15.
//  Copyright (c) 2015 Shengbin Meng. All rights reserved.
//

#import "AudioEncoder.h"

@implementation AudioEncoder

- (id) init {
    self = [super init];
    if (self) {
        self.sampleRate = 44100;
        self.channelCount = 2;
        self.bitrate = 20000;
    }
    return self;
}

- (void) setSampleRate:(int)sampleRate channelCount:(int)channelCount bitrate:(int)bitrate {
    self.sampleRate = sampleRate;
    self.channelCount = channelCount;
    self.bitrate = bitrate;
}

- (int) open {
    NSLog(@"AudioEncoder open");
    return 0;
}

- (int) encode {
    NSLog(@"AudioEncoder encode");
    return 0;
}


- (int) close {
    NSLog(@"AudioEncoder close");
    return 0;
}

@end
