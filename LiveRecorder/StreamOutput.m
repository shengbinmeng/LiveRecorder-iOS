//
//  StreamOutput.m
//  LiveRecorder
//
//  Created by Shengbin Meng on 9/15/15.
//  Copyright (c) 2015 Shengbin Meng. All rights reserved.
//

#import "StreamOutput.h"

@implementation StreamOutput
{
    long _videoByteCount;
    long _audioByteCount;
    NSDate *_audioByteCountBeginTime;
    NSDate *_videoByteCountBeginTime;
}

- (int) open:(NSString*) address {
    NSLog(@"StreamOutput open: %@", address);
    return 0;
}

- (int) didReceiveEncodedAudio:(NSData*) audioData presentationTime:(CMTime)pts {
    NSLog(@"StreamOutput didReceiveEncodedAudio");
    if (_audioByteCountBeginTime == nil) {
        _audioByteCountBeginTime = [NSDate date];
        _audioByteCount = 0;
    } else {
        _audioByteCount += audioData.length;
        NSDate *currentTime = [NSDate date];
        double interval = [currentTime timeIntervalSinceDate:_audioByteCountBeginTime];
        if (interval > 1.0) {
            self.audioBitrateInKbps = _audioByteCount * 8 / interval / 1000;
            _audioByteCountBeginTime = currentTime;
            _audioByteCount = 0;

        }
    }
    return 0;
}

- (int) didReceiveEncodedVideo:(NSData*) videoData presentationTime:(CMTime)pts isKeyFrame:(BOOL)keyFrame {
    NSLog(@"StreamOutput didReceiveEncodedVideo");
    if (_videoByteCountBeginTime == nil) {
        _videoByteCountBeginTime = [NSDate date];
        _videoByteCount = 0;
    } else {
        _videoByteCount += videoData.length;
        NSDate *currentTime = [NSDate date];
        double interval = [currentTime timeIntervalSinceDate:_videoByteCountBeginTime];
        if (interval > 1.0) {
            self.videoBitrateInKbps = _videoByteCount * 8 / interval / 1000;
            _videoByteCountBeginTime = currentTime;
            _videoByteCount = 0;
        }
    }
    return 0;
}

- (int) close {
    NSLog(@"StreamOutput close");
    _videoByteCountBeginTime = nil;
    _audioByteCountBeginTime = nil;
    return 0;
}

@end
