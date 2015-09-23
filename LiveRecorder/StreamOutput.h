//
//  StreamOutput.h
//  LiveRecorder
//
//  Created by Shengbin Meng on 9/15/15.
//  Copyright (c) 2015 Shengbin Meng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface StreamOutput : NSObject

@property double videoBitrateInKbps;
@property double audioBitrateInKbps;

- (int) open:(NSString*) address;
- (int) didReceiveEncodedAudio:(NSData*) audioData presentationTime:(CMTime)pts;
- (int) didReceiveEncodedVideo:(NSData*) videoData presentationTime:(CMTime)pts isKeyFrame:(BOOL)keyFrame;
- (int) close;

@end
