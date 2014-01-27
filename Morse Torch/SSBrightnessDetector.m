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

#define NORMALIZE_MAX 25
#define BRIGHTNESS_THRESHOLD 115
#define MIN_BRIGHTNESS_THRESHOLD 95

#define LOW_LIGHT_CONDITIONS_MAX 
#define AVG_LIGHT_CONDITIONS_MAX
#define HIGH_LIGHT_CONDITIONS_MAX

@interface SSBrightnessDetector() <AVCaptureAudioDataOutputSampleBufferDelegate>

//session to capture brightness
@property (nonatomic) AVCaptureSession *captureSession;

//bool containing session hasStarted
@property (nonatomic) BOOL hasStarted;

//bool containing whether normalization has finished and is ready to receive data
@property (nonatomic) BOOL normalizationFinished;

//the calibration brightness average
@property (nonatomic) CGFloat thisCalibrationAvg;

//the array of all calibrated brightness values
@property (nonatomic) NSMutableArray *calibrationNumbers;

//the time evaluated that the brightness is beyond the threshold
@property (nonatomic) NSTimeInterval timeBeyondThreshold;

//the matrix of brightness RGB values in the given camera view
@property (nonatomic) NSMutableArray *brightnessMatrix;

//the last brightness value below the threshold
@property (nonatomic) int lastTotalBrightnessValue;

@property (nonatomic) int brightnessThreshold;

@end

@implementation SSBrightnessDetector

+(SSBrightnessDetector*) sharedManager {
    static dispatch_once_t pred;
    static SSBrightnessDetector *shared;
    
    dispatch_once(&pred, ^{
        shared = [[SSBrightnessDetector alloc] init];
    });
    return shared;
}

- (void)setup
{
    self.hasStarted = NO;
    self.timeBeyondThreshold = 0.f;
    self.brightnessThreshold = BRIGHTNESS_THRESHOLD;
    self.calibrationNumbers = [[NSMutableArray alloc] init];
    [NSThread detachNewThreadSelector:@selector(initCapture) toTarget:self withObject:nil];
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
        [self resetCalibration];
        [self.captureSession startRunning];
        self.hasStarted = YES;
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
        [self.calibrationNumbers removeAllObjects];
    }
    return self.hasStarted;
}

-(void) resetCalibration {
    self.brightnessMatrix = [NSMutableArray new];
    self.normalizationFinished = NO;
    self.lastTotalBrightnessValue = 0.f;
}

-(void) setThesholdWithSensitivity: (CGFloat) sensitivity; {
    self.brightnessThreshold = BRIGHTNESS_THRESHOLD+sensitivity;
    NSLog(@"%i",self.brightnessThreshold);
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

#pragma mark - getBrightness and send Notification (hybridized)
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (CVPixelBufferLockBaseAddress(imageBuffer, 0) == kCVReturnSuccess)
    {
        UInt8 *base = (UInt8 *)CVPixelBufferGetBaseAddress(imageBuffer);
        
        //  calculate average brightness in a simple way
        
        size_t bytesPerRow      = CVPixelBufferGetBytesPerRow(imageBuffer);
        size_t width            = CVPixelBufferGetWidth(imageBuffer);
        size_t height           = CVPixelBufferGetHeight(imageBuffer);
        UInt32 totalBrightness  = 0;
        
        int counter_row=0;
        BOOL firstRun = NO;
        
        if ([self.brightnessMatrix count] == 0) {
            firstRun = YES;
        }
        
        for (UInt8 *rowStart = base; counter_row < height; rowStart += bytesPerRow, counter_row++){
            
            //get last brightness at row if possible
            NSMutableArray *row;
            if ([self.brightnessMatrix count] == height) {
                row = [self.brightnessMatrix objectAtIndex:counter_row];
            } else {
                row = [NSMutableArray new];
            }
            
            //cycle through columns at row
            int counter_column = 0;
            for (UInt8 *p = rowStart; counter_column<width; p += 4, counter_column++){
                
                UInt32 thisBrightness = (.299*p[0] + .587*p[1] + .116*p[2]);
                if ([self.calibrationNumbers count] < NORMALIZE_MAX) {
                    //calibrate matrix
                    if ([row count] == width) {
                        //if matrix has entries
                        thisBrightness = (thisBrightness+[[row objectAtIndex:counter_column] intValue])/2;
                        [row removeObjectAtIndex:counter_column];
                        [row insertObject:[NSNumber numberWithInt:thisBrightness] atIndex:counter_column];
                    } else {
                        //if first time matrix is created
                        [row addObject:[NSNumber numberWithInt:thisBrightness]];
                    }
                } else {
                    //calibration exists
//                    if (thisBrightness <2*[[row objectAtIndex:counter_column] intValue]) {
//                        thisBrightness = thisBrightness-[[row objectAtIndex:counter_column] intValue];
//                    }
                }
                totalBrightness += thisBrightness;
                
            }
            
            //put row values intro matrix
            if ([self.brightnessMatrix count] == height) {
                [self.brightnessMatrix removeObjectAtIndex:counter_row];
                [self.brightnessMatrix insertObject:row atIndex:counter_row];
            } else {
                [self.brightnessMatrix addObject:row];
            }
        }
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
        
        if (!firstRun) {
            [self sendNotificationByBrightness:totalBrightness];
        } else {
            self.lastTotalBrightnessValue = totalBrightness;
        }
    }
}

-(void)sendNotificationByBrightness: (int) totalBrightness {

    if ([self.calibrationNumbers count] == NORMALIZE_MAX){
        if (!self.normalizationFinished) {
            int thisBrightness = [self calculateLevelOfBrightness:totalBrightness];
            
            if (thisBrightness == 100) {
                self.normalizationFinished = YES;
            } else {
                self.lastTotalBrightnessValue = totalBrightness;
                [self normalizeWithBrightness:totalBrightness];
            }
        } else {
            //proceed if lens is calibrated
            int thisBrightness = [self calculateLevelOfBrightness:totalBrightness];
            
            NSLog(@"%i",thisBrightness);
            
            if( thisBrightness > MIN_BRIGHTNESS_THRESHOLD ){
                
                if(thisBrightness > self.brightnessThreshold ) {
                    
                    //check to how long we are above threshold & recalibrate if needed
                    if (self.timeBeyondThreshold == 0.f) {
                        
                        self.timeBeyondThreshold = [NSDate timeIntervalSinceReferenceDate];
                    }
                    if ([NSDate timeIntervalSinceReferenceDate]-self.timeBeyondThreshold > 2.f) {
                        
                        //recalibrate
                        self.brightnessMatrix = [NSMutableArray new];
                        [self.calibrationNumbers removeAllObjects];
                    } else {
                        
                        //send Light ON notification
                        [[NSNotificationCenter defaultCenter] postNotificationName:@"OnReceiveLightDetected"
                                                                            object:nil];
                    }
                } else {
                    
                    //send Light OFF notification
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"OnReceiveLightNotDetected"
                                                                        object:nil];
                    self.lastTotalBrightnessValue = totalBrightness;
                    self.timeBeyondThreshold = 0.f;
                }
            }else{
                
                //send Light OFF notification
                [[NSNotificationCenter defaultCenter] postNotificationName:@"OnReceiveLightNotDetected"
                                                                    object:nil];
                self.lastTotalBrightnessValue = totalBrightness;
                self.timeBeyondThreshold = 0.f;
            }
        }
    } else {
        //calibrate with given light scheme
        [self normalizeWithBrightness:totalBrightness];
        if ([self.calibrationNumbers count] == NORMALIZE_MAX) {
            self.thisCalibrationAvg = 0.f;
            self.lastTotalBrightnessValue = totalBrightness;
            [[NSNotificationCenter defaultCenter] postNotificationName:@"hideHubForCalibration" object:nil];
        }
        CGFloat calibrationProgress = (float)[self.calibrationNumbers count]/NORMALIZE_MAX;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"displayHubForCalibration"
                                                            object:nil
                                                          userInfo:@{@"progress":[NSNumber numberWithFloat:calibrationProgress]
                                                                     }];
    }
}

-(int) calculateLevelOfBrightness:(int) pCurrentBrightness
{
    return (pCurrentBrightness*100) /self.lastTotalBrightnessValue;
}

#pragma mark - Normalizing
-(NSInteger) getCalibratedAvgBrightness {
    if (self.thisCalibrationAvg == 0.f) {
        NSNumber *sum = [self.calibrationNumbers valueForKeyPath:@"@sum.self"];
        self.thisCalibrationAvg = [sum integerValue]/[self.calibrationNumbers count];
    }
    return self.thisCalibrationAvg;
}


-(void) normalizeWithBrightness:(NSInteger) thisBrightness {
    [self.calibrationNumbers insertObject:[NSNumber numberWithInteger:thisBrightness] atIndex:0];
    if ([self.calibrationNumbers count] > NORMALIZE_MAX){
        [self.calibrationNumbers removeLastObject];
    }
}

#pragma mark -John Clem amazingness
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
