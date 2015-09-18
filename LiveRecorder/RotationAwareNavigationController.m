//
//  RotationAwareNavigationController.m
//  LiveRecorder
//
//  Created by Shengbin Meng on 9/16/15.
//  Copyright (c) 2015 Shengbin Meng. All rights reserved.
//

#import "RotationAwareNavigationController.h"

@interface RotationAwareNavigationController ()

@end

@implementation RotationAwareNavigationController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return self.topViewController.supportedInterfaceOrientations;
}

- (BOOL)shouldAutorotate {
    return [self.topViewController shouldAutorotate];
}


@end
