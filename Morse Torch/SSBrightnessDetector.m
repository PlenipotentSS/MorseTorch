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

#define NORMALIZE_MAX 20

@interface SSBrightnessDetector() <AVCaptureAudioDataOutputSampleBufferDelegate>
@property (nonatomic) AVCaptureSession *captureSession;
@property (nonatomic) BOOL hasStarted;
@property (nonatomic) CGFloat threshold;
@property (nonatomic) NSMutableArray *normalizingNumbers;
@property (nonatomic) BOOL brightnessTriggered;
@property (nonatomic) NSTimeInterval timeBeyondThreshold;
@end

@implementation SSBrightnessDetector

- (id)init
{
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup
{
    self.hasStarted = NO;
    self.timeBeyondThreshold = 0.f;
    self.threshold = 0.f;
    self.normalizingNumbers = [[NSMutableArray alloc] init];
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

#pragma mark - getBrightness and send Notification

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
        
        for (UInt8 *rowStart = base; height; rowStart += bytesPerRow, height --)
        {
            size_t columnCount = width;
            for (UInt8 *p = rowStart; columnCount; p += 4, columnCount --)
            {
                UInt32 value = (p[0] + p[1] + p[2]);
                totalBrightness += value;
            }
        }
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
        totalBrightness /= 1000;
        
        if ([self.normalizingNumbers count] == NORMALIZE_MAX ){
            CGFloat normalized = (float)totalBrightness/[self getNormalizedBrightness];
            if (normalized > 2*self.threshold){
                if (self.timeBeyondThreshold == 0.f) {
                    self.timeBeyondThreshold = [NSDate timeIntervalSinceReferenceDate];
                } else if ([NSDate timeIntervalSinceReferenceDate]-self.timeBeyondThreshold > .5f) {
                    [self normalizeWithBrightness:totalBrightness];
                    self.threshold = (float)totalBrightness/[self getNormalizedBrightness];
                }
                NSLog(@"norm: %f : thresh: %f",normalized, self.threshold);
                [[NSNotificationCenter defaultCenter] postNotificationName:@"OnReceiveLightDetected" object:nil];
                self.brightnessTriggered = YES;
            } else {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"OnReceiveLightNotDetected" object:nil];
                [self normalizeWithBrightness:totalBrightness];
                self.threshold = (float)totalBrightness/[self getNormalizedBrightness];
                self.timeBeyondThreshold = 0.f;
            }
        } else {
            [self normalizeWithBrightness:totalBrightness];
            self.threshold = (float)totalBrightness/[self getNormalizedBrightness];
        }
    }
    
}

#pragma mark - Normalizing
-(NSInteger) getNormalizedBrightness {
    NSNumber *sum = [self.normalizingNumbers valueForKeyPath:@"@sum.self"];
    NSInteger average = [sum integerValue]/[self.normalizingNumbers count];
    return average;
}


-(void) normalizeWithBrightness:(NSInteger) thisBrightness {
    [self.normalizingNumbers insertObject:[NSNumber numberWithInteger:thisBrightness] atIndex:0];
    if ([self.normalizingNumbers count] > NORMALIZE_MAX){
        [self.normalizingNumbers removeLastObject];
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
