//
//  SSReceiveViewController.m
//  Morse Torch
//
//  Created by Stevenson on 1/22/14.
//  Copyright (c) 2014 Steven Stevenson. All rights reserved.
//

#import "SSReceiveViewController.h"
#import "SSTorchAccess.h"
#import "SSMorseButton.h"
#import "NSString+MorseCode.h"
#import "SSBrightnessDetector.h"
#import <M13ProgressSuite/M13ProgressHUD.h>
#import <M13ProgressSuite/M13ProgressViewRing.h>
#import "SSAppDelegate.h"

@interface SSReceiveViewController ()

// UILabels to display morse code to user
@property (weak, nonatomic) IBOutlet UILabel *receivedText;
@property (weak, nonatomic) IBOutlet UILabel *morseText;

//UIButton class to start receiving messages
@property (weak, nonatomic) IBOutlet SSMorseButton *receiveButton;

//time intervals to configure to morse code configurations
@property (nonatomic) NSTimeInterval flashStarted;
@property (nonatomic) NSTimeInterval flashEnded;
@property (nonatomic) NSTimeInterval pauseDurationBetweenFlashes;

//local storage of current morse code being decoded
@property (nonatomic) NSMutableArray *symbolArrays;

//scrollview for current view
@property (weak, nonatomic) IBOutlet UIScrollView *theScrollView;

//the HUD that shows the current progress of the text being sent
@property (nonatomic) M13ProgressHUD *hudProgress;

//slider providing sensitivity
@property (weak, nonatomic) IBOutlet UISlider *sensitivitySlider;
@end

@implementation SSReceiveViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    //listeners for light detection
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveLightDetected:) name:@"OnReceiveLightDetected" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveLightNotDetected:) name:@"OnReceiveLightNotDetected" object:nil];
    
    //listeners for light calibration
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(displayHubForCalibration:) name:@"displayHubForCalibration" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hideHubForCalibration:) name:@"hideHubForCalibration" object:nil];
    
    self.receivedText.layer.cornerRadius = 5;
    self.receivedText.layer.masksToBounds = YES;
    
    self.morseText.layer.cornerRadius = 5;
    self.morseText.layer.masksToBounds = YES;
    
    self.receiveButton.layer.cornerRadius = 5;
    self.receiveButton.layer.masksToBounds = YES;
    
    [[SSBrightnessDetector sharedManager] setup];
    
    [self.sensitivitySlider addTarget:self action:@selector(updateSensitivity) forControlEvents:UIControlEventValueChanged];
    
    //initialize the magicevents
    self.symbolArrays = [[NSMutableArray alloc] init];
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:YES];
    self.theScrollView.contentOffset = CGPointMake(0, 0);
    self.theScrollView.contentSize = CGSizeMake(320.f, 460.f);
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if ([[SSTorchAccess sharedManager] isTransmitting] ){
        if (![[SSBrightnessDetector sharedManager] isReceiving]) {
            self.receiveButton.enabled = NO;
            [self.receiveButton  setDisabled];
            [self.receiveButton setAlpha:.5f];
        }
    } else {
        if (![[SSBrightnessDetector sharedManager] isReceiving]) {
            self.receiveButton.enabled = YES;
            [self.receiveButton  setReceive];
            [self.receiveButton setAlpha:1.f];
        }
        self.receiveButton.enabled = YES;
        [self.receiveButton setAlpha:1.f];
    }
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -IBActions
-(IBAction)receiveButtonPressed
{
    if (![[SSBrightnessDetector sharedManager] isReceiving]){
        NSLog(@"Magic Events Reader");
        [[SSBrightnessDetector sharedManager] start];
        [self.receiveButton  setCancel];
        
        //prepare textfield
        [self.receivedText setText:@""];
        self.receivedText.textAlignment = NSTextAlignmentLeft;
        
        //prepare morse field
        [self.morseText setText:@""];
        self.morseText.textAlignment = NSTextAlignmentLeft;
        
        [self.symbolArrays removeAllObjects];
        self.flashStarted = 0.f;
        self.flashEnded = 0.f;
        self.pauseDurationBetweenFlashes = 0.f;
    } else {
        [[SSBrightnessDetector sharedManager] stop];
        [self.receiveButton  setReceive];
        if (self.hudProgress) {
            [self resetHUD];
        }
        NSLog(@"%@",self.symbolArrays);
    }
}

-(void) updateSensitivity {
    [[SSBrightnessDetector sharedManager] setThesholdWithSensitivity:self.sensitivitySlider.value];
}

#pragma mark - SSBrightness Calibrating Notification
-(void) displayHubForCalibration:(NSNotification *) notification {
    if (!self.hudProgress) {
        [[NSOperationQueue mainQueue ] addOperationWithBlock:^{
            self.hudProgress = [[M13ProgressHUD alloc] initWithProgressView:[[M13ProgressViewRing alloc] init]];
            self.hudProgress.progressViewSize = CGSizeMake(60.0, 60.0);
            [self.view addSubview:self.hudProgress];
            self.hudProgress.status = @"Calibrating";
            
            [self.hudProgress show:YES];
        }];
    }else {
        CGFloat caliProgress = [(NSNumber*)[[notification userInfo] objectForKey:@"progress"] floatValue];
        [[NSOperationQueue mainQueue ] addOperationWithBlock:^{
            [self.hudProgress setProgress:caliProgress animated:YES];
        }];
    }
}

-(void) hideHubForCalibration:(NSNotification *) notification {
    if (self.hudProgress) {
        [[NSOperationQueue mainQueue ] addOperationWithBlock:^{
            [self performSelector:@selector(setCompleteHUD) withObject:nil afterDelay:self.hudProgress.animationDuration + .1];
        }];
    }
}

-(void) setCompleteHUD {
    [self.hudProgress performAction:M13ProgressViewActionSuccess animated:YES];
    [self performSelector:@selector(resetHUD) withObject:nil afterDelay:1.5];
}

-(void) resetHUD {
    [self.hudProgress hide:YES];
    self.hudProgress = nil;
}

#pragma mark - SSBrightness Detection notifications
-(void)receiveLightDetected:(NSNotification *) notification
{
    CGFloat offDuration = [NSDate timeIntervalSinceReferenceDate]-self.pauseDurationBetweenFlashes;
    BOOL updateUI = NO;
    if (!self.flashStarted) {
        self.flashStarted = [NSDate timeIntervalSinceReferenceDate];
        if (offDuration > .5f ) {
            updateUI = YES;
        }
        //NSLog(@"%f",offDuration);
    } else if ( [self.symbolArrays count] != 0 && offDuration > 1.f ) {
        updateUI = YES;
    } else {
        
    }
    
    if (updateUI) {
        NSString *morseWord = @"";
        for (NSString *symbol in self.symbolArrays) {
            morseWord = [NSString stringWithFormat:@"%@%@",morseWord,symbol];
        }
        NSString *letter = [NSString letterForMorseWord:morseWord];
        //NSLog(@"%@ : %@",morseWord, letter);
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            //update letter field
            NSString *textSoFar = self.receivedText.text;
            [self.receivedText setText:[NSString stringWithFormat:@"%@ %@",textSoFar,letter]];
            
            //update morse symbol field
            NSString *symbolsSoFar = self.morseText.text;
            [self.morseText setText:[NSString stringWithFormat:@"%@ ",symbolsSoFar]];
        }];
        [self.symbolArrays removeAllObjects];
        self.pauseDurationBetweenFlashes = 0.f;
    }
}

-(void) showCalibratingHUD {
    
}

-(void)receiveLightNotDetected:(NSNotification *) notification
{
    self.flashEnded = [NSDate timeIntervalSinceReferenceDate];
    if (self.flashStarted) {
        //if the flash was detected & now checking to see what symbol was found
        
        CGFloat duration = self.flashEnded-self.flashStarted;
        NSString *symbol = @"";
        if (duration < .25) {
            symbol = @".";
        } else if (duration < 1.f) {
            symbol = @"_";
        }
        NSLog(@"%f -> %@",duration,symbol);
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            NSString *textSoFar = self.morseText.text;
            [self.morseText setText:[NSString stringWithFormat:@"%@%@",textSoFar,symbol]];
        }];
        [self.symbolArrays addObject:symbol];
        self.flashStarted = 0.f;
        self.pauseDurationBetweenFlashes = [NSDate timeIntervalSinceReferenceDate];
    } else {
        //if there is anything left in the array during a long pause
        CGFloat offDuration = self.flashEnded-self.pauseDurationBetweenFlashes;
        if (offDuration > 1.f && [self.symbolArrays count] > 0) {
            NSString *morseWord = @"";
            for (NSString *symbol in self.symbolArrays) {
                morseWord = [NSString stringWithFormat:@"%@%@",morseWord,symbol];
            }
            NSString *letter = [NSString letterForMorseWord:morseWord];
            //NSLog(@"%@ : %@",morseWord, letter);
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                //update letter field
                NSString *textSoFar = self.receivedText.text;
                [self.receivedText setText:[NSString stringWithFormat:@"%@ %@",textSoFar,letter]];
                
                //update morse symbol field
                NSString *symbolsSoFar = self.morseText.text;
                [self.morseText setText:[NSString stringWithFormat:@"%@ ",symbolsSoFar]];
            }];
            [self.symbolArrays removeAllObjects];
            self.pauseDurationBetweenFlashes = 0.f;
        }
    }
}

@end
