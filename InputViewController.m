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
#import "SSNSOperation.h"

@import AVFoundation;

@interface InputViewController () <UITextFieldDelegate,SSNOperationDelegate>
@property (weak, nonatomic) IBOutlet UITextField *inputField;
@property (weak, nonatomic) IBOutlet UILabel *morseText;
@property (weak, nonatomic) IBOutlet UILabel *letterText;
@property (weak, nonatomic) IBOutlet UIButton *transmitButton;
@property (nonatomic) NSOperationQueue *torchQueue;
@property (nonatomic) AVCaptureDevice *device;

@property (weak, nonatomic) IBOutlet UIPageControl *pageControl;

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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textFieldDidChange:) name:UITextFieldTextDidChangeNotification object:nil];
	
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
        NSString *inputText =self.inputField.text;
        NSString *validatedText = [NSString validateString:inputText];
        NSArray* morse = [NSString getSymbolsFromString:inputText];
        
        
        SSNSOperation *op = [[SSNSOperation alloc] initWithMorseArray:morse andString:validatedText];
        op.delegate = self;
        [self.torchQueue addOperation:op];
        [self.torchQueue addOperationWithBlock:^{
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                [self setTransmitting];
            }];
        }];
        NSLog(@"%lu",(unsigned long)self.torchQueue.operationCount);
    } else {
        [self.torchQueue cancelAllOperations];
        [self setTransmitting];
    }
}

#pragma mark - InputViewController.h
- (void)updateTextLabelText:(NSString*) text andMorseLabelText: (NSString*)morseChar {
    self.letterText.text = text;
    [self.letterText setNeedsDisplay];
    self.morseText.text = morseChar;
    [self.morseText setNeedsDisplay];
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

-(void)textFieldDidEndEditing:(UITextField *)textField {
    self.transmitButton.enabled = YES;
}

-(void)textFieldDidBeginEditing:(UITextField *)textField {
    self.transmitButton.enabled = NO;
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}


#pragma mark UITextFieldDidChange
-(void)textFieldDidChange: (NSNotification *) notification {
    [self switchDisabledToTransmit];
}

#pragma mark switch button
-(void)switchDisabledToTransmit {
    if(self.torchQueue.operationCount == 0) {
        if ([self.inputField.text length] == 0) {
            self.transmitButton.enabled = NO;
            [self setDisabled];
            [self.transmitButton setAlpha:.5f];
        } else {
            [self setTransmitting];
            self.transmitButton.enabled = YES;
            [self.transmitButton setAlpha:1.f];
        }
    }
}

@end



