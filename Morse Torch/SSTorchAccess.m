//
//  SSTorchAccess.m
//  Morse Torch
//
//  Created by Stevenson on 1/22/14.
//  Copyright (c) 2014 Steven Stevenson. All rights reserved.
//

#import "SSTorchAccess.h"
@import AVFoundation;

@interface  SSTorchAccess()

@property (nonatomic) AVCaptureDevice *device;
@property (atomic) BOOL transmitting;

@end

@implementation SSTorchAccess

+(SSTorchAccess*) sharedManager {
    static dispatch_once_t pred;
    static SSTorchAccess *shared;
    
    dispatch_once(&pred, ^{
        shared = [[SSTorchAccess alloc] init];
    });
    return shared;
}

-(void) takeTorch {
    if (!self.device) {
        self.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    _transmitting = YES;
}

-(BOOL) isTransmitting {
    return self.transmitting;
}

-(void) releaseTorch {
    _transmitting = NO;
}

#pragma mark - Torch Operations
-(void) engageTorch {
    if ([self.device hasFlash]) {
        [self.device lockForConfiguration:nil];
        [self.device setTorchMode:AVCaptureTorchModeOn];
        [self.device unlockForConfiguration];
    }
}

-(void) disengageTorch {
    if ([self.device hasTorch]) {
        [self.device lockForConfiguration:nil];
        [self.device setTorchMode:AVCaptureTorchModeOff];
        [self.device unlockForConfiguration];
    }
}

@end
