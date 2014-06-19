//
//  SSBrightnessDetector.m
//  Morse Torch
//
//  Created by Stevenson on 1/24/14.
//  Copyright (c) 2014 Steven Stevenson. All rights reserved.
//
//
// Rewritten by Steven Stevenson, but original concept by CFMagicEvents
//
//

#import "SSBrightnessDetector.h"
#import <AVFoundation/AVFoundation.h>

#define TOTAL_REQUIRED_CALIBRATION_SHOTS 20

@interface SSBrightnessDetector() <AVCaptureAudioDataOutputSampleBufferDelegate>

//session to capture brightness
@property (nonatomic) AVCaptureSession *captureSession;

//bool containing session hasStarted
@property (nonatomic) BOOL hasStarted;

//the matrix of brightness RGB values in the given camera view
//@property (nonatomic) NSMutableArray *brightnessMatrix;

//first derivative values of light function
@property (nonatomic, strong) NSMutableArray *firstDegreeLightValues;

@property (nonatomic, strong) NSMutableArray *lastLightMatrix;

@property (nonatomic) CGFloat lastPeakAcceleration;

@property (nonatomic) BOOL isCalibrated;

@property (nonatomic) NSInteger numberOfCalibratedShots;

@property (nonatomic) CGFloat averageOfCalibrations;

@property (nonatomic) NSInteger numberOfNullNotifications;

@property (nonatomic, copy) void (^notificationBlock)(void);

@property (nonatomic) BOOL isEvaluatingHigh;

@property (nonatomic) CGFloat expectedPeak;

@end

@implementation SSBrightnessDetector

+(SSBrightnessDetector*) sharedManager {
    static dispatch_once_t pred;
    static SSBrightnessDetector *shared;
    
    dispatch_once(&pred, ^{
        shared = [[SSBrightnessDetector alloc] init];
        if (!shared.captureSession) {
            [shared setup];
        }
    });
    return shared;
}

- (void)setup
{
    self.hasStarted = NO;
    [NSThread detachNewThreadSelector:@selector(initCapture) toTarget:self withObject:nil];
    
    self.notificationBlock = ^{};
}

- (void)initCapture {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSError *error = nil;
    
    AVCaptureDevice *captureDevice = [self getBackCamera];
    [self configureCameraForHighestFrameRate:captureDevice];
    if ([captureDevice isExposureModeSupported:AVCaptureExposureModeLocked]) {
        [captureDevice lockForConfiguration:nil];
        [captureDevice setExposureMode:AVCaptureExposureModeLocked];
        [captureDevice unlockForConfiguration];
    } else {
        NSLog(@"device doesn't support exposure lock");
    }
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
    if ( ! videoInput)
    {
        NSLog(@"Could not get video input: %@", error);
        return;
    }
    //  the capture session is where all of the inputs and outputs tie together.
    _captureSession = [[AVCaptureSession alloc] init];
    
    //  sessionPreset governs the quality of the capture. we don't need high-resolution images,
    //  so we'll set the session preset to low quality.
    
    _captureSession.sessionPreset = AVCaptureSessionPresetLow;
    
    [_captureSession addInput:videoInput];
    
    //  create the thing which captures the output
    AVCaptureVideoDataOutput *videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    
    //  pixel buffer format
    // YUV (iOS 7 Chroma/Luminance standard) --- NOT INCLUDED
    NSDictionary *settings = [[NSDictionary alloc] initWithObjectsAndKeys:
                              [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA],
                              kCVPixelBufferPixelFormatTypeKey, nil];
    videoDataOutput.videoSettings = settings;
    [settings release];
    
    //  we need a serial queue for the video capture delegate callback
    dispatch_queue_t queue = dispatch_queue_create("com.zuckerbreizh.cf", NULL);

    [videoDataOutput setSampleBufferDelegate:(id)self queue:queue];
    [_captureSession addOutput:videoDataOutput];
    [videoDataOutput release];
    
    dispatch_release(queue);
    [pool release];
    
}

-(BOOL)start
{
    if(!self.hasStarted){
        [self.captureSession startRunning];
        
        self.hasStarted = YES;
        self.isCalibrated = NO;
        self.numberOfCalibratedShots = 0;
        self.averageOfCalibrations = 0;
        self.expectedPeak = 0;
        self.isEvaluatingHigh = NO;
    }
    return self.hasStarted;
}

-(BOOL)isReceiving {
    return self.hasStarted;
}

-(BOOL)stop
{
    if(self.hasStarted){
        [self.captureSession stopRunning];
        self.hasStarted = NO;
    }
    return self.hasStarted;
}


- (AVCaptureDevice *)getBackCamera
{
    NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in videoDevices)
    {
        if (device.position == AVCaptureDevicePositionBack)
        {
            return device;
        }
    }
    return nil;
}

- (AVCaptureDevice *)getFrontCamera
{
    NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in videoDevices)
    {
        if (device.position == AVCaptureDevicePositionFront)
        {
            return device;
        }
    }
    return nil;
}

#pragma mark calibrate changes
- (void)calibrateChanges:(CGFloat)thisAvgAcc
{
    NSLog(@"calibrating: %f",thisAvgAcc);
    
    if (thisAvgAcc < 1 && thisAvgAcc > -1 ){
        self.numberOfCalibratedShots++;
        self.averageOfCalibrations += thisAvgAcc;
    } else {
        self.numberOfCalibratedShots = 0;
        self.averageOfCalibrations = 0;
    }
    NSNumber *currentProgress = [NSNumber numberWithFloat:(self.numberOfCalibratedShots/TOTAL_REQUIRED_CALIBRATION_SHOTS)];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"displayHubForCalibration"
                                                        object:nil
                                                      userInfo:@{@"progress": currentProgress}];
    
    if (self.numberOfCalibratedShots > TOTAL_REQUIRED_CALIBRATION_SHOTS) {
        self.isCalibrated = YES;
        self.averageOfCalibrations /= TOTAL_REQUIRED_CALIBRATION_SHOTS;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"hideHubForCalibration" object:nil];
    }
}

#pragma mark - AVCaptureAudioDataOutputSampleBuffer getBrightness and send Notification 

-(BOOL) passedExpected:(CGFloat)thisAvgAcc
{
    if (self.expectedPeak != 0) {
        CGFloat dissimilarityRatio = (self.expectedPeak-thisAvgAcc)/self.expectedPeak;
        
        NSLog(@"acc: %f, peak: %f, lastpeak: %f, dissimilarity: %f",thisAvgAcc, self.expectedPeak, self.lastPeakAcceleration, dissimilarityRatio);
        if (dissimilarityRatio > 0) {
            return NO;
        }
    } else {
        self.expectedPeak = thisAvgAcc;
    }
    return YES;
}

- (void)sendNotifications:(CGFloat)thisAvgAcc withTotalBrightnessChange:(CGFloat)brightnessChange
{
    
    NSLog(@"%f",brightnessChange);
    if (brightnessChange > 0 ) {
        if (thisAvgAcc > 1) {
            //the speed of change is larger than normal
            
            self.notificationBlock = ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"OnReceiveLightDetected" object:nil];
            };
            
            self.isEvaluatingHigh = YES;
            self.lastPeakAcceleration = thisAvgAcc;
            self.numberOfNullNotifications = 0;
        } else if ( (self.isEvaluatingHigh && thisAvgAcc < self.lastPeakAcceleration *.55) || self.numberOfNullNotifications > 3) {
            //the speed of change is not as large
            
            self.notificationBlock = ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"OnReceiveLightNotDetected" object:nil];
            };
            
            self.isEvaluatingHigh = NO;
            self.lastPeakAcceleration = 0;
        } else {
            //count where neither conditions are met
            
            self.numberOfNullNotifications++;
        }
    } else {
        self.notificationBlock = ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"OnReceiveLightNotDetected" object:nil];
        };
    }
    
    //send the notification
    self.notificationBlock();
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (CVPixelBufferLockBaseAddress(imageBuffer, 0) == kCVReturnSuccess)
    {
        
        NSMutableArray *brightnessMatrix = [[[NSMutableArray alloc] init] autorelease];
        NSMutableArray *tentativeFirstDegreeMatrix = [[[NSMutableArray alloc] init] autorelease];
        
        UInt8 *base = (UInt8 *)CVPixelBufferGetBaseAddress(imageBuffer);
        
        //  calculate average brightness in a simple way
        
        size_t bytesPerRow      = CVPixelBufferGetBytesPerRow(imageBuffer);
        size_t width            = CVPixelBufferGetWidth(imageBuffer);
        size_t height           = CVPixelBufferGetHeight(imageBuffer);
        
        int counter_row=0;
        BOOL firstRun = NO;
        
        if ([brightnessMatrix count] == 0) {
            firstRun = YES;
        }
        
        CGFloat totalAccelerationChange = 0;
        NSInteger totalEvaluatedValues = 0;
        CGFloat totalBrightnessChanges = 0;
        
        for (UInt8 *rowStart = base; counter_row < height; rowStart += bytesPerRow, counter_row++){
            
            //get last brightness at row if possible
            NSMutableArray *row = [[NSMutableArray new] autorelease];
            NSMutableArray *row1st = [[NSMutableArray new] autorelease];
            
            //cycle through columns at row
            int counter_column = 0;
            for (UInt8 *p = rowStart; counter_column<width; p += 4, counter_column++){
                Float32 thisBrightness = (.299*p[0] + .587*p[1] + .116*p[2]);
                [row addObject:@(thisBrightness)];
                
                //if one iteration has occurred
                if (self.lastLightMatrix) {
                    
                    CGFloat lastBrightness = [[[self.lastLightMatrix objectAtIndex:counter_row] objectAtIndex:counter_column] floatValue];
                    
                    //detect 1st degree changes
                    Float32 brightnessChange = (thisBrightness-lastBrightness); //d(x) = f(x+1)-f(x)
                    totalBrightnessChanges += brightnessChange;
                    
                   [row1st addObject:@(brightnessChange)];
                    
                    //detect 2nd degree changes
                    CGFloat oldBrightnessChange = [[[self.firstDegreeLightValues objectAtIndex:counter_row] objectAtIndex:counter_column] floatValue] ;
                    
                    Float32 brightnessAcceleration = brightnessChange - oldBrightnessChange; //d(x+1)-d(x)

                    //cumulative values
                    totalAccelerationChange += brightnessAcceleration;
                    totalEvaluatedValues++;
                    
                } else {
                    [row1st addObject:@(0)];
                }
            }
            [brightnessMatrix insertObject:row atIndex:counter_row];
            [tentativeFirstDegreeMatrix insertObject:row1st atIndex:counter_row];
            
        }
        
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
        
        CGFloat thisAvgAcc = totalAccelerationChange/totalEvaluatedValues;
        
        //calibrate and send notifications when ready
        if (self.isCalibrated) {
            
            [self sendNotifications:thisAvgAcc withTotalBrightnessChange:totalBrightnessChanges];
        } else if (!self.isCalibrated) {
            
            [self calibrateChanges:thisAvgAcc];
            
            if (self.isCalibrated) {
                
                NSLog(@"calibrated with brightness: %f",totalBrightnessChanges);
            }
        }
        
        //don't save light changes if evaluating high
        if (!self.isEvaluatingHigh) {
            self.firstDegreeLightValues = tentativeFirstDegreeMatrix;
            
            self.lastLightMatrix = brightnessMatrix;
        }
    }
}

#pragma mark iOS Docs
- (void)configureCameraForHighestFrameRate:(AVCaptureDevice *)device
{
    AVCaptureDeviceFormat *bestFormat = nil;
    AVFrameRateRange *bestFrameRateRange = nil;
    for ( AVCaptureDeviceFormat *format in [device formats] ) {
        for ( AVFrameRateRange *range in format.videoSupportedFrameRateRanges ) {
            if ( range.maxFrameRate > bestFrameRateRange.maxFrameRate ) {
                bestFormat = format;
                bestFrameRateRange = range;
            }
        }
    }
    if ( bestFormat ) {
        if ( [device lockForConfiguration:NULL] == YES ) {
            device.activeFormat = bestFormat;
            device.activeVideoMinFrameDuration = bestFrameRateRange.minFrameDuration;
            device.activeVideoMaxFrameDuration = bestFrameRateRange.minFrameDuration;
            [device unlockForConfiguration];
        }
    }
}
@end
