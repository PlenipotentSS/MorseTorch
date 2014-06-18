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

@property (nonatomic) int currentSpeed;


@property (nonatomic) BOOL areViewsSetup;

//first derivative values of light function
@property (nonatomic) NSMutableArray *firstDegreeLightValues;

//second derivative values of light function
@property (nonatomic) NSMutableArray *secondDegreeLightValues;

@property (nonatomic,strong) NSMutableArray *lastLightMatrix;

@property (nonatomic) CGFloat lastAverageAcceleration;

@property (nonatomic) BOOL peakFlag;

@property (nonatomic) BOOL isCalibrated;

@property (nonatomic) NSInteger numberOfCalibratedShots;

@property (nonatomic) CGFloat averageOfCalibrations;

@property (nonatomic) NSInteger numberOfNullNotifications;

@property (nonatomic, copy) void (^notificationBlock)(void);

@property (nonatomic) BOOL isEvaluatingHigh;

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
        self.isCalibrated = NO;
        self.numberOfCalibratedShots = 0;
        self.hasStarted = YES;
        self.averageOfCalibrations = 0;
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

-(void)shouldUseSlowerSpeed:(BOOL)slowerSpeed
{
    if (slowerSpeed) {
        self.currentSpeed = 500000;
    } else {
        self.currentSpeed = 10000;
    }
}

#pragma mark calibrate changes
- (void)calibrateChanges:(CGFloat)thisAvgAcc
{
    if (thisAvgAcc < 1 && thisAvgAcc > -1 ){
        self.numberOfCalibratedShots++;
        self.averageOfCalibrations += thisAvgAcc;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"displayHubForCalibration"
                                                            object:nil
                                                          userInfo:@{@"progress":[NSNumber numberWithFloat:(self.numberOfCalibratedShots/TOTAL_REQUIRED_CALIBRATION_SHOTS)]
                                                                     }];
    } else {
        self.numberOfCalibratedShots = 0;
        self.averageOfCalibrations = 0;
    }
    if (self.numberOfCalibratedShots > TOTAL_REQUIRED_CALIBRATION_SHOTS) {
        self.isCalibrated = YES;
        self.averageOfCalibrations /= TOTAL_REQUIRED_CALIBRATION_SHOTS;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"hideHubForCalibration" object:nil];
    }
}

#pragma mark - AVCaptureAudioDataOutputSampleBuffer getBrightness and send Notification 
- (void)sendNotifications:(CGFloat)thisAvgAcc
{
    if (thisAvgAcc > 1  ) { //1 may need to be the sensitivity slider!
        self.notificationBlock = ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"OnReceiveLightDetected" object:nil];
        };
        self.isEvaluatingHigh = YES;
        self.numberOfNullNotifications = 0;
    } else if (thisAvgAcc < -15 || self.numberOfNullNotifications > 5) {
        self.notificationBlock = ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"OnReceiveLightNotDetected" object:nil];
        };
        
        self.isEvaluatingHigh = NO;
    } else {
        self.numberOfNullNotifications++;
        
    }
    
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
        
        NSMutableArray *tentativeSecondDegreeMatrix = [[[NSMutableArray alloc] init] autorelease];
        
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
        CGFloat totalBrightness = 0.f;
        
        for (UInt8 *rowStart = base; counter_row < height; rowStart += bytesPerRow, counter_row++){
            
            //get last brightness at row if possible
            NSMutableArray *row = [[NSMutableArray new] autorelease];
            NSMutableArray *row1st = [[NSMutableArray new] autorelease];
            NSMutableArray *row2st = [[NSMutableArray new] autorelease];
            
            //cycle through columns at row
            int counter_column = 0;
            for (UInt8 *p = rowStart; counter_column<width; p += 4, counter_column++){
                Float32 thisBrightness = (.299*p[0] + .587*p[1] + .116*p[2]);
                [row addObject:@(thisBrightness)];
                totalBrightness += thisBrightness;
                
                
                if (self.lastLightMatrix) {
                    
                    NSNumber *lastBrightNumber = [[self.lastLightMatrix objectAtIndex:counter_row] objectAtIndex:counter_column];
                    CGFloat lastBrightness = [lastBrightNumber floatValue];
                    
                    CGFloat brightnessChange = (thisBrightness-lastBrightness); //d(x) = f(x+1)-f(x)
                    

                    NSNumber *oldBrightChangeNumber = [[self.firstDegreeLightValues objectAtIndex:counter_row] objectAtIndex:counter_column];
                    CGFloat oldBrightnessChange = [oldBrightChangeNumber floatValue];
                    
                    if (!self.isEvaluatingHigh) {
                        [[self.firstDegreeLightValues objectAtIndex:counter_row] replaceObjectAtIndex:counter_column withObject:@(brightnessChange)];
                    }
                        
                    CGFloat brightnessAcceleration = brightnessChange-oldBrightnessChange; //d(x+1)-d(x)
                    
                    //increased the number of changed pixels
                    
                    if (!self.isEvaluatingHigh) {
                        [[self.secondDegreeLightValues objectAtIndex:counter_row] replaceObjectAtIndex:counter_column withObject:@(brightnessAcceleration)];
                    }
                    
                    totalAccelerationChange += brightnessChange;
                    
                    totalEvaluatedValues++;
                    
                }
            }
            [brightnessMatrix insertObject:row atIndex:counter_row];
        }
        
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
        
        CGFloat thisAvgAcc = totalAccelerationChange/totalEvaluatedValues;
        
        //calibrate and send notifications when ready
        if (self.isCalibrated) {
            
            NSLog(@"%f w/ %f",totalBrightness,thisAvgAcc);
            
            [self sendNotifications:thisAvgAcc];
        
            
            if (self.lastLightMatrix) {
                self.lastLightMatrix = nil;
                [self.lastLightMatrix release];
            }
            self.lastAverageAcceleration = thisAvgAcc;
        } else {
            
            [self calibrateChanges:thisAvgAcc];
            
            NSLog(@"calibrated with brightness: %f",totalBrightness);
        }
        
        //don't save light matrix if evaluating high
        if (!self.isEvaluatingHigh) {
            self.lastLightMatrix = brightnessMatrix;
        }
    }
}


//- (void)setupBase:(NSMutableArray*)lightMatrix
//{
//    NSLog(@"setting up arrays...");
//    self.firstDegreeLightValues = [[[NSMutableArray alloc] init] autorelease];
//    self.secondDegreeLightValues = [[[NSMutableArray alloc] init] autorelease];
//    for (NSInteger i = 0; i<[lightMatrix count]; i++) {
//        if ([self.firstDegreeLightValues count] == i ) {
//            [self.firstDegreeLightValues addObject:[[NSMutableArray new] autorelease]];
//            [self.secondDegreeLightValues addObject:[[NSMutableArray new] autorelease]];
//        }
//        
//        NSMutableArray *row = [[lightMatrix objectAtIndex:i] autorelease];
//        
//        for (NSInteger j = 0; j<[row count]; j++) {
//            
//            [[self.firstDegreeLightValues objectAtIndex:i] addObject:@(0)];
//            [[self.secondDegreeLightValues objectAtIndex:i] addObject:@(0)];
//        }
//        [self.firstDegreeLightValues objectAtIndex:i];
//        [self.secondDegreeLightValues objectAtIndex:i];
//    }
//}

#pragma mark -Source: John Clem
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
