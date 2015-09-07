//
//  CaptureView.m
//  LiveRecorder
//
//  Created by Shengbin Meng on 9/7/15.
//  Copyright (c) 2015 Shengbin Meng. All rights reserved.
//

#import "CaptureView.h"

@implementation CaptureView

+ (Class)layerClass {
    return [AVCaptureVideoPreviewLayer class];
}

// Getter.
- (AVCaptureSession *)session {
    AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.layer;
    return previewLayer.session;
}

// Setter.
- (void)setSession:(AVCaptureSession *)session {
    AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.layer;
    previewLayer.session = session;
}

@end
