//
//  InputViewController.m
//  Morse Torch
//
//  Created by Stevenson on 1/20/14.
//  Copyright (c) 2014 Steven Stevenson. All rights reserved.
//

#import "InputViewController.h"
#import "NSString+MorseCode.h"
#import "UIColor+MorseTorch.h"

@import AVFoundation;

@interface InputViewController () <UITextFieldDelegate>
@property (weak, nonatomic) IBOutlet UITextField *inputField;
@property (weak, nonatomic) IBOutlet UILabel *morseText;
@property (weak, nonatomic) IBOutlet UIButton *transmitButton;
@property (nonatomic) NSOperationQueue *torchQueue;
@property (nonatomic) AVCaptureDevice *device;

@end

@implementation InputViewController

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
    
    self.inputField.delegate = self;
    self.torchQueue = [[NSOperationQueue alloc] init];
    self.torchQueue.name = @"Torch Queue";
    [self.torchQueue setMaxConcurrentOperationCount:1];
    
    self.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
	
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -
- (IBAction)transmitString:(id)sender {
    if (self.torchQueue.operationCount == 0) {
        [self setCancel];
        NSArray* morse = [NSString getSymbolsFromString:self.inputField.text];
        NSString *morseString;
        
        for (NSString* code in morse) {
            if (morseString) {
                morseString = [NSString stringWithFormat:@"%@ %@",morseString,code];
            } else {
                morseString = code;
            }
            for (NSUInteger i=0;i<[code length];i++) {
                NSString *dotOrDash = [code substringWithRange:NSMakeRange(i, 1)];
                
                [self.torchQueue addOperationWithBlock:^{
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                        [self.morseText setText:morseString];
                    }];
                }];
                if ([dotOrDash isEqualToString:@"."]) {
                    [self.torchQueue addOperationWithBlock:^{
                        [self engageTorch];
                        usleep(DOT_IN_MICROSEC);
                        [self disengageTorch];
                    }];
                } else if ([dotOrDash isEqualToString:@"_"]) {
                    [self.torchQueue addOperationWithBlock:^{
                        [self engageTorch];
                        usleep(DASH_IN_MICROSEC);
                        [self disengageTorch];
                    }];
                }
                [self.torchQueue addOperationWithBlock:^{
                    usleep(LETTER_DELAY_IN_MICROSEC);
                }];
            }
            [self.torchQueue addOperationWithBlock:^{
                usleep(WORD_DELAY_IN_MICROSEC);
            }];
        }
        
        [self.torchQueue addOperationWithBlock:^{
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                [self setTransmitting];
            }];
        }];
    } else {
        [self.torchQueue cancelAllOperations];
        [self setTransmitting];
    }
}

#pragma mark Button Methods
-(void) setCancel {
    [self.transmitButton setTitle:@"Cancel" forState:UIControlStateNormal];
    [self.transmitButton setTintColor:[UIColor getCancelTintColor]];
    [self.transmitButton setBackgroundColor:[UIColor getCancelBgColor]];
}

-(void) setTransmitting {
    [self.transmitButton setTitle:@"Transmit" forState:UIControlStateNormal];
    [self.transmitButton setBackgroundColor:[UIColor getTransmitBgColor]];
    [self.transmitButton setTintColor:[UIColor getTransmitTintColor]];
}

-(void) setDisabled {
    [self.transmitButton setBackgroundColor:[UIColor groupTableViewBackgroundColor]];
    [self.transmitButton setTintColor:[UIColor lightGrayColor]];
    self.transmitButton.enabled = NO;
}

#pragma mark - Torch Operations
-(void) engageTorch {
    if ([self.device hasFlash]) {
        [self.device lockForConfiguration:nil];
        [self.device setTorchMode:AVCaptureTorchModeOn];  // use AVCaptureTorchModeOff to turn off
        [self.device unlockForConfiguration];
    }
}

-(void) disengageTorch {
    if ([self.device hasTorch]) {
        [self.device lockForConfiguration:nil];
        [self.device setTorchMode:AVCaptureTorchModeOff];  // use AVCaptureTorchModeOff to turn off
        [self.device unlockForConfiguration];
    }
}

#pragma mark - UITextFieldDelegate
-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if ( [self.inputField isFirstResponder]) {
        [self.inputField resignFirstResponder];
    }
}

-(void)textFieldDidBeginEditing:(UITextField *)textField {
    self.transmitButton.enabled = NO;
    [self setDisabled];
}

-(void)textFieldDidEndEditing:(UITextField *)textField  {
    if ([textField.text length] == 0) {
        self.transmitButton.enabled = NO;
        [self setDisabled];
    } else {
        [self setTransmitting];
        self.transmitButton.enabled = YES;
    }
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

@end