//
//  CaptureViewController.m
//  LiveRecorder
//
//  Created by Shengbin Meng on 9/4/15.
//  Copyright (c) 2015 Shengbin Meng. All rights reserved.
//

#import "CaptureViewController.h"
#import <Photos/Photos.h>
#import "CaptureView.h"
#import "CoreRecorder.h"

typedef NS_ENUM(NSInteger, CaptureSetupResult) {
    CaptureSetupResultSuccess,
    CaptureSetupResultCameraNotAuthorized,
    CaptureSetupResultSessionConfigurationFailed
};

@interface CaptureViewController () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, CoreRecorderDelegate>

@property (strong, nonatomic) IBOutlet CaptureView *captureView;
@property (strong, nonatomic) IBOutlet UIButton *cameraButton;
@property (strong, nonatomic) IBOutlet UIButton *recordButton;
@property (strong, nonatomic) IBOutlet UILabel *infoLabel;

@property (nonatomic) dispatch_queue_t sessionQueue;
@property (nonatomic) AVCaptureSession *session;
@property (nonatomic) AVCaptureDeviceInput *videoDeviceInput;

@property (nonatomic) AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic) AVCaptureAudioDataOutput *audioDataOutput;

@property (nonatomic) CaptureSetupResult setupResult;
@property (nonatomic) UIBackgroundTaskIdentifier backgroundRecordingID;
@property (nonatomic) BOOL isRecording;

@property (nonatomic) CoreRecorder *recorder;
@property (atomic) NSString *recorderInfo;

@end

@implementation CaptureViewController
{
    long _frameCount;
    NSDate *_frameCountBeginTime;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.isRecording = NO;

    // Disable UI. The UI is enabled if and only if the session starts running.
    self.cameraButton.enabled = NO;
    self.recordButton.enabled = NO;
    self.infoLabel.text = nil;

    
    // Create the AVCaptureSession.
    self.session = [[AVCaptureSession alloc] init];
    
    // Setup the capture view.
    self.captureView.session = self.session;
    
    // Communicate with the session and other session objects on this queue.
    self.sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
    
    self.setupResult = CaptureSetupResultSuccess;
    
    // Check video authorization status. Video access is required and audio access is optional.
    // If audio access is denied, audio is not recorded during movie recording.
    switch ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo]) {
        case AVAuthorizationStatusAuthorized: {
            // The user has previously granted access to the camera.
            break;
        }
        case AVAuthorizationStatusNotDetermined: {
            // The user has not yet been presented with the option to grant video access.
            // We suspend the session queue to delay session setup until the access request has completed to avoid
            // asking the user for audio access if video access is denied.
            // Note that audio access will be implicitly requested when we create an AVCaptureDeviceInput for audio during session setup.
            dispatch_suspend(self.sessionQueue);
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                if (!granted) {
                    self.setupResult = CaptureSetupResultCameraNotAuthorized;
                }
                dispatch_resume(self.sessionQueue);
            }];
            break;
        }
        default: {
            // The user has previously denied access.
            self.setupResult = CaptureSetupResultCameraNotAuthorized;
            break;
        }
    }

    // Setup the capture session.
    // In general it is not safe to mutate an AVCaptureSession or any of its inputs, outputs, or connections from multiple threads at the same time.
    // Why not do all of this on the main queue?
    // Because -[AVCaptureSession startRunning] is a blocking call which can take a long time. We dispatch session setup to the sessionQueue
    // so that the main queue isn't blocked, which keeps the UI responsive.
    dispatch_async(self.sessionQueue, ^{
        if (self.setupResult != CaptureSetupResultSuccess) {
            return;
        }
        
        [self.session beginConfiguration];
        
        [self.session setSessionPreset:[NSString stringWithString:AVCaptureSessionPreset640x480]];
        
        // Add video input.
        NSError *error = nil;
        AVCaptureDevice *videoDevice = [CaptureViewController deviceWithMediaType:AVMediaTypeVideo preferringPosition:AVCaptureDevicePositionBack];
        AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
        if (!videoDeviceInput) {
            NSLog(@"Could not create video device input: %@", error);
        }
        if ([self.session canAddInput:videoDeviceInput]) {
            [self.session addInput:videoDeviceInput];
            self.videoDeviceInput = videoDeviceInput;
            dispatch_async(dispatch_get_main_queue(), ^{
                // Use the status bar orientation as the initial video orientation. Subsequent orientation changes are handled by [viewWillTransitionToSize:withTransitionCoordinator:].
                UIInterfaceOrientation statusBarOrientation = [UIApplication sharedApplication].statusBarOrientation;
                AVCaptureVideoOrientation initialVideoOrientation = AVCaptureVideoOrientationPortrait;
                if (statusBarOrientation != UIInterfaceOrientationUnknown) {
                    initialVideoOrientation = (AVCaptureVideoOrientation)statusBarOrientation;
                }
                AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.captureView.layer;
                previewLayer.connection.videoOrientation = initialVideoOrientation;
            });
        } else {
            NSLog(@"Could not add video device input to the session");
            self.setupResult = CaptureSetupResultSessionConfigurationFailed;
        }
        
        // Add audio input.
        AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
        AVCaptureDeviceInput *audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
        if (!audioDeviceInput) {
            NSLog(@"Could not create audio device input: %@", error);
        }
        if ([self.session canAddInput:audioDeviceInput]) {
            [self.session addInput:audioDeviceInput];
        } else {
            NSLog(@"Could not add audio device input to the session");
        }
        
        // Add video data output.
        AVCaptureVideoDataOutput *videoDataOutput = [AVCaptureVideoDataOutput new];
        [videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
        NSDictionary *rawOutputSettings = [NSDictionary dictionaryWithObject:
                                           [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
        [videoDataOutput setVideoSettings:rawOutputSettings];
        dispatch_queue_t videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
        [videoDataOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];
        
        if ([self.session canAddOutput:videoDataOutput]) {
            [self.session addOutput:videoDataOutput];
            self.videoDataOutput = videoDataOutput;
        } else {
            NSLog(@"Could not add video data output to the session");
            self.setupResult = CaptureSetupResultSessionConfigurationFailed;
        }
        
        // Add audio data output.
        AVCaptureAudioDataOutput *audioDataOutput = [AVCaptureAudioDataOutput new];
        dispatch_queue_t audioDataOutputQueue = dispatch_queue_create("AudioDataOutputQueue", DISPATCH_QUEUE_SERIAL);
        [audioDataOutput setSampleBufferDelegate:self queue:audioDataOutputQueue];
        if ([self.session canAddOutput:audioDataOutput]) {
            [self.session addOutput:audioDataOutput];
            self.audioDataOutput = audioDataOutput;
        } else {
            NSLog(@"Could not add audio data output to the session");
            self.setupResult = CaptureSetupResultSessionConfigurationFailed;
        }
        
        [self.session commitConfiguration];
        
        self.recorder = [[CoreRecorder alloc] init];
        
        // Set these values according to actual configuration. Or pass 0 to let the recorder determine itself.
        int sampleRate = 0;
        int channelCount = 0;
        int audioBitrate = 0;
        int width = 640;
        int height = 480;
        int frameRate = 0;
        int videoBitrate = 0;
        CREncoderType videoEncoderType = CREncoderTypeHardwareVideo;
        NSString *outputAddress = @"/";
        
        if (self.configuration != nil && ![self.configuration isEqualToString:@""]) {
            NSArray *configArray = [self.configuration componentsSeparatedByString:@" "];
            NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
            for (NSString *config in configArray) {
                NSArray *pair = [config componentsSeparatedByString:@":"];
                NSString *name = [pair objectAtIndex:0];
                NSString *value = [pair objectAtIndex:1];
                if ([name caseInsensitiveCompare:@"videoBitrate"] == NSOrderedSame) {
                    videoBitrate = [formatter numberFromString:value].intValue;
                } else if ([name caseInsensitiveCompare:@"videoEncoder"] == NSOrderedSame) {
                    if ([value caseInsensitiveCompare:@"hardware"] == NSOrderedSame) {
                        videoEncoderType = CREncoderTypeHardwareVideo;
                    } else if ([value caseInsensitiveCompare:@"software"] == NSOrderedSame) {
                        videoEncoderType = CREncoderTypeSoftwareVideo;
                    }
                }
            }
        }
        
        if (self.outputAddress != nil && ![self.outputAddress isEqualToString:@""]) {
            outputAddress = self.outputAddress;
        }
        
        [self.recorder setSampleRate:sampleRate channelCount:channelCount audioBitrate:audioBitrate width:width height:height frameRate:frameRate videoBitrate:videoBitrate outputAddress:outputAddress];
        self.recorder.videoEncoderType = videoEncoderType;
        self.recorder.delegate = self;
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // Make the navigation bar transparent.
    self.navigationController.navigationBar.shadowImage = [UIImage new];
    [self.navigationController.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
}

- (void)viewWillDisappear:(BOOL)animated {
    // Undo "Make the navigation bar transparent".
    [self.navigationController.navigationBar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.shadowImage = nil;
    [super viewWillDisappear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    dispatch_async(self.sessionQueue, ^{
        switch (self.setupResult) {
            case CaptureSetupResultSuccess:
            {
                // Only setup observers and start the session running if setup succeeded.
                [self.session startRunning];
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.cameraButton.enabled = ([AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo].count > 1);
                    self.recordButton.enabled = YES;
                });
                break;
            }
            case CaptureSetupResultCameraNotAuthorized:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSString *message = NSLocalizedString(@"The app doesn't have permission to use the camera, please change privacy settings.", @"Alert message when the user has denied access to the camera");
                    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Message" message:message preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"Alert OK button") style:UIAlertActionStyleCancel handler:nil];
                    [alertController addAction:cancelAction];
                    // Provide quick access to Settings.
                    UIAlertAction *settingsAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Settings", @"Alert button to open Settings") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
                    }];
                    [alertController addAction:settingsAction];
                    [self presentViewController:alertController animated:YES completion:nil];
                });
                break;
            }
            case CaptureSetupResultSessionConfigurationFailed:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSString *message = NSLocalizedString(@"Unable to capture media becasue capture session setup failed.", @"Alert message when something goes wrong during capture session configuration");
                    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Message" message:message preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"Alert OK button") style:UIAlertActionStyleCancel handler:nil];
                    [alertController addAction:cancelAction];
                    [self presentViewController:alertController animated:YES completion:nil];
                });
                break;
            }
        }
    } );

}

- (void)viewDidDisappear:(BOOL)animated {
    
    dispatch_async(self.sessionQueue, ^{
        if (self.session.isRunning) {
            [self.session stopRunning];
        }
        if (self.isRecording) {
            [self stopRecording];
        }
    });
    
    [super viewDidDisappear:animated];
}

#pragma mark Orientation

- (BOOL)shouldAutorotate {
    // Disable autorotation of the interface when recording is in progress.
    return !self.isRecording;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    // The device orientation is different from UI orientation.
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
    if (UIDeviceOrientationIsPortrait(deviceOrientation) || UIDeviceOrientationIsLandscape(deviceOrientation)) {
        AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.captureView.layer;
        previewLayer.connection.videoOrientation = (AVCaptureVideoOrientation)deviceOrientation;
    }
}


#pragma mark Actions

- (void)startRecording {
    // Update the orientation on the output video connection before starting recording.
    AVCaptureConnection *connection = [self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.captureView.layer;
    connection.videoOrientation = previewLayer.connection.videoOrientation;
    if (connection.videoOrientation == AVCaptureVideoOrientationPortrait || connection.videoOrientation == AVCaptureVideoOrientationPortraitUpsideDown) {
        int height = self.recorder.height;
        int width = self.recorder.width;
        [self.recorder setWidth:height];
        [self.recorder setHeight:width];
    }
    
    // Start our recording.
    [self.recorder start];
    self.cameraButton.enabled = NO;
    [self.recordButton setTitle:NSLocalizedString(@"Stop", @"Recording button stop title") forState:UIControlStateNormal];
    self.isRecording = YES;
}

- (void)stopRecording {
    // Stop our recording.
    self.isRecording = NO;
    self.cameraButton.enabled = ([AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo].count > 1);
    [self.recordButton setTitle:NSLocalizedString(@"Start", @"Recording button record title") forState:UIControlStateNormal];
    [self.infoLabel setText:nil];
    [self.recorder stop];
}

- (IBAction)toggleRecording:(id)sender {
    if (self.isRecording) {
        [self stopRecording];
    } else {
        [self startRecording];
    }
}

- (IBAction)changeCamera:(id)sender {
    // Disable the buttons. They will be enabled when change is finished.
    self.cameraButton.enabled = NO;
    self.recordButton.enabled = NO;
    
    dispatch_async(self.sessionQueue, ^{
        AVCaptureDevice *currentVideoDevice = self.videoDeviceInput.device;
        AVCaptureDevicePosition currentPosition = currentVideoDevice.position;
        
        AVCaptureDevicePosition preferredPosition = AVCaptureDevicePositionUnspecified;
        switch (currentPosition) {
            case AVCaptureDevicePositionUnspecified:
            case AVCaptureDevicePositionFront:
                preferredPosition = AVCaptureDevicePositionBack;
                break;
            case AVCaptureDevicePositionBack:
                preferredPosition = AVCaptureDevicePositionFront;
                break;
        }
        
        AVCaptureDevice *videoDevice = [CaptureViewController deviceWithMediaType:AVMediaTypeVideo preferringPosition:preferredPosition];
        AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:nil];
        
        [self.session beginConfiguration];
        
        // Remove the existing device input first, since using the front and back camera simultaneously is not supported.
        [self.session removeInput:self.videoDeviceInput];
        
        if ([self.session canAddInput:videoDeviceInput]) {
            [self.session addInput:videoDeviceInput];
            self.videoDeviceInput = videoDeviceInput;
        } else {
            NSLog(@"Could not add video device input to the session");
            [self.session addInput:self.videoDeviceInput];
        }
        
        AVCaptureConnection *connection = [self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
        if (connection.isVideoStabilizationSupported) {
            connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
        }
        
        [self.session commitConfiguration];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.cameraButton.enabled = YES;
            self.recordButton.enabled = YES;
        });
    });
}

#pragma mark Data Output Delegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (self.isRecording == NO) {
        return;
    }
    if (captureOutput == self.videoDataOutput) {
        [self.recorder didReceiveVideoSamples:sampleBuffer];
        if (_frameCountBeginTime == nil) {
            _frameCountBeginTime = [NSDate date];
            _frameCount = 0;
        } else {
            _frameCount++;
            NSDate *currentTime = [NSDate date];
            NSTimeInterval interval = [currentTime timeIntervalSinceDate:_frameCountBeginTime];
            if (interval > 1.0) {
                double frameRate = _frameCount / interval;
                _frameCountBeginTime = currentTime;
                _frameCount = 0;
                
                NSString *videoInfo = [NSString stringWithFormat:@"Video size: %dx%d, frame rate: %.1f", self.recorder.width, self.recorder.height, frameRate];
                NSString *bitrateInfo = [NSString stringWithFormat:@"Video bitrate %.1f kbps, audio bitrate: %.1f kbps", self.recorder.output.videoBitrateInKbps, self.recorder.output.audioBitrateInKbps];
                NSString *infoText = [NSString stringWithFormat:@"%@;%@", videoInfo, bitrateInfo];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.infoLabel setText:infoText];
                });
            }
        }
    } else if (captureOutput == self.audioDataOutput) {
        [self.recorder didReceiveAudioSamples:sampleBuffer];
    }
}

#pragma mark Device Configuration

+ (AVCaptureDevice *)deviceWithMediaType:(NSString *)mediaType preferringPosition:(AVCaptureDevicePosition)position {
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:mediaType];
    AVCaptureDevice *captureDevice = devices.firstObject;
    for (AVCaptureDevice *device in devices) {
        if (device.position == position) {
            captureDevice = device;
            break;
        }
    }
    return captureDevice;
}

#pragma mark Core Recorder Delegate

- (void)recorder:(CoreRecorder *)recorder didStartRecording:(NSString *)information {
    NSLog(@"Recorder started.");
}

- (void)recorder:(CoreRecorder *)recorder didStopRecording:(NSString *)information {
    NSLog(@"Recorder stopped.");
}


@end
