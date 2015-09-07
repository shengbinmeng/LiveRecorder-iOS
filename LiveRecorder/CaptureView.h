//
//  CaptureView.h
//  LiveRecorder
//
//  Created by Shengbin Meng on 9/7/15.
//  Copyright (c) 2015 Shengbin Meng. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface CaptureView : UIView
@property (nonatomic) AVCaptureSession *session;
@end
