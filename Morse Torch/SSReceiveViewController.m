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

@interface SSReceiveViewController ()
@property (weak, nonatomic) IBOutlet UILabel *receivedText;
@property (weak, nonatomic) IBOutlet UILabel *morseText;
@property (weak, nonatomic) IBOutlet SSMorseButton *receiveButton;
@property (nonatomic) BOOL isReceiving;

@property (nonatomic) NSTimeInterval flashStarted;
@property (nonatomic) NSTimeInterval flashEnded;
@property (nonatomic) NSTimeInterval pauseDurationBetweenFlashes;
@property (weak, nonatomic) IBOutlet UIView *flashVideoView;
@property (nonatomic) NSMutableArray *symbolArrays;

@end

@implementation SSReceiveViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveLightDetected:) name:@"OnReceiveLightDetected" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveLightNotDetected:) name:@"OnReceiveLightNotDetected" object:nil];
    
    self.receivedText.layer.cornerRadius = 5;
    self.receivedText.layer.masksToBounds = YES;
    self.morseText.layer.cornerRadius = 5;
    self.morseText.layer.masksToBounds = YES;
    
    //initialize the magicevents
    self.brightnessDetector = [[SSBrightnessDetector alloc] init];
    self.symbolArrays = [[NSMutableArray alloc] init];

}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if ([[SSTorchAccess sharedManager] isTransmitting] ){
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Transmitting" message:@"Please Wait While the current Code is Transmitting" delegate:self cancelButtonTitle:@"Okay" otherButtonTitles:nil];
        [alertView show];
        self.receiveButton.enabled = NO;
        [self.receiveButton  setDisabled];
        [self.receiveButton setAlpha:.5f];
    } else {
        if (![self.brightnessDetector isReceiving]) {
            self.receiveButton.enabled = YES;
            [self.receiveButton  setReceive];
            [self.receiveButton setAlpha:1.f];
        }
    }
}

-(IBAction)receiveButtonPressed
{
    if (!self.isReceiving){
        NSLog(@"Magic Events Reader");
        [self.brightnessDetector start];
        self.isReceiving = YES;
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
        [self.brightnessDetector stop
         ];
        self.isReceiving = NO;
        [self.receiveButton  setReceive];
        NSLog(@"%@",self.symbolArrays);
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)receiveLightDetected:(NSNotification *) notification
{
    CGFloat offDuration = [NSDate timeIntervalSinceReferenceDate]-self.pauseDurationBetweenFlashes;
    BOOL updateUI = NO;
    if (!self.flashStarted) {
        self.flashStarted = [NSDate timeIntervalSinceReferenceDate];
        NSLog(@"%f",offDuration);
        if (offDuration > .5 ) {
            updateUI = YES;
        }
    } else if ( [self.symbolArrays count] != 0 && offDuration > 1.f ) {
        updateUI = YES;
    }
    
    if (updateUI) {
        NSString *morseWord = @"";
        for (NSString *symbol in self.symbolArrays) {
            morseWord = [NSString stringWithFormat:@"%@%@",morseWord,symbol];
        }
        NSString *letter = [NSString letterForMorseWord:morseWord];
        NSLog(@"%@ : %@",morseWord, letter);
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

-(void)receiveLightNotDetected:(NSNotification *) notification
{
    self.flashEnded = [NSDate timeIntervalSinceReferenceDate];
    if (self.flashStarted) {
        //if the flash was detected & now checking to see what symbol was found
        
        CGFloat duration = self.flashEnded-self.flashStarted;
        NSString *symbol = @"";
        if (duration < .3) {
            symbol = @".";
        } else if (duration < .5) {
            symbol = @"_";
        }
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
            NSLog(@"%@ : %@",morseWord, letter);
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
