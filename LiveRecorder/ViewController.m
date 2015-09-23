//
//  ViewController.m
//  LiveRecorder
//
//  Created by Shengbin Meng on 9/4/15.
//  Copyright (c) 2015 Shengbin Meng. All rights reserved.
//

#import "ViewController.h"
#import "CaptureViewController.h"

@interface ViewController () <UITextFieldDelegate>
@property (strong, nonatomic) IBOutlet UITextField *configTextField;
@property (strong, nonatomic) IBOutlet UITextField *addressTextField;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self.configTextField setDelegate:self];
    [self.addressTextField setDelegate:self];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)textFieldShouldReturn:(UITextField *)theTextField {
    [theTextField resignFirstResponder];
    return YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    if ([segue.identifier isEqualToString:@"ShowCapture"]) {
        CaptureViewController *captureViewController = [segue destinationViewController];
        captureViewController.configuration = self.configTextField.text;
        captureViewController.outputAddress = self.addressTextField.text;
    }
}


@end
