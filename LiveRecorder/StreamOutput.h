//
//  StreamOutput.h
//  LiveRecorder
//
//  Created by Shengbin Meng on 9/15/15.
//  Copyright (c) 2015 Shengbin Meng. All rights reserved.
//

#import <Foundation/Foundation.h>
@import AVFoundation;

@interface StreamOutput : NSObject

- (int) open:(NSString*) address;
- (int) didReceiveEncodedAudio:(CMSampleBufferRef) sampleBuffer;
- (int) didReceiveEncodedVideo:(CMSampleBufferRef) sampleBuffer;
- (int) close;

@end
