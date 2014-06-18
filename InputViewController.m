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
#import "SSProgressViewRingGradient.h"
#import "SSTorchAccess.h"
#import "SSMorseButton.h"
#import "SSResponsiveScrollView.h"

@import AVFoundation;

@interface InputViewController () <UITextFieldDelegate, UIScrollViewDelegate>

//the UILabel containing text to encode in flashes
@property (weak, nonatomic) IBOutlet UITextField *inputField;

//the UIButton to send the text
@property (weak, nonatomic) IBOutlet SSMorseButton *transmitButton;

//the UILabels to show the current letter and morse word being sent
@property (weak, nonatomic) IBOutlet UILabel *morseText;
@property (weak, nonatomic) IBOutlet UILabel *letterText;

//the background queue containing the flashes
@property (nonatomic) NSOperationQueue *torchQueue;

//the HUD that shows the current progress of the text being sent
@property (nonatomic) SSProgressViewRingGradient *hudProgress;

//UI objects for content wrapping
@property (weak, nonatomic) IBOutlet UIView *theInputView;
@property (weak, nonatomic) IBOutlet SSResponsiveScrollView *theScrollView;

@end

@implementation InputViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.inputField.delegate = self;
    self.torchQueue = [[NSOperationQueue alloc] init];
    [self.torchQueue setMaxConcurrentOperationCount:1];

    [self setup];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textFieldDidChange:) name:UITextFieldTextDidChangeNotification object:nil];
    
    [self.theScrollView setTextFields:@[self.inputField]];
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:YES];
    self.theScrollView.contentOffset = CGPointMake(0, 0);
    self.theScrollView.contentSize = CGSizeMake(320.f, 460.f);
}

#pragma mark Setup Views
-(void) setup {
    self.hudProgress = [[SSProgressViewRingGradient alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    self.hudProgress.center = CGPointMake(CGRectGetMidX(self.view.frame), CGRectGetMaxY(self.transmitButton.frame)+CGRectGetHeight(self.transmitButton.frame)+20);
    self.hudProgress.showPercentage = NO;
    
    [self.theInputView addSubview:self.hudProgress];
    [self.hudProgress setProgress:0.0f animated:YES];
    
    self.letterText.layer.cornerRadius = 5;
    self.letterText.layer.masksToBounds = YES;
    self.morseText.layer.cornerRadius = 5;
    self.morseText.layer.masksToBounds = YES;
    
    self.transmitButton.layer.cornerRadius = 5;
    self.transmitButton.layer.masksToBounds = YES;
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Transmit using many operations
- (IBAction)transmitString:(id)sender {
    if ([self.inputField isFirstResponder]) {
        [self.inputField resignFirstResponder];
    }
    if (self.torchQueue.operationCount == 0) {
        [[SSTorchAccess sharedManager] takeTorch];
        [self.transmitButton setCancel];
        NSString *inputText = [NSString validateString:self.inputField.text];
        NSArray* morse = [NSString getSymbolsFromString:inputText];
    
        CGFloat totalProcess = [morse count];
        CGFloat segmentedProcess = (1.f/(float)totalProcess);
        NSInteger counter = 0;
        CGFloat ongoingSegment = 0;
        for (NSString* code in morse) {
            for (NSUInteger i=0;i<[code length];i++) {
                NSString *dotOrDash = [code substringWithRange:NSMakeRange(i, 1)];
                
                [self.torchQueue addOperationWithBlock:^{
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                        
                        CGFloat thisProgress = (float)(i+1)/(float)[code length]*segmentedProcess+ongoingSegment;
                        [self.hudProgress setProgress:thisProgress animated:YES];
                        
                        unichar charString = [inputText characterAtIndex:counter];
                        [self updateTextLabelText: [NSString stringWithFormat:@"%c",charString] andMorseLabelText: code];
                        
                    }];
                }];
                if ([dotOrDash isEqualToString:@"."]) {
                    [self.torchQueue addOperationWithBlock:^{
                        [[SSTorchAccess sharedManager] engageTorch];
                        usleep(DOT_IN_MICROSEC);
                        [[SSTorchAccess sharedManager] disengageTorch];
                    }];
                } else if ([dotOrDash isEqualToString:@"_"]) {
                    [self.torchQueue addOperationWithBlock:^{
                        [[SSTorchAccess sharedManager] engageTorch];
                        usleep(DASH_IN_MICROSEC);
                        [[SSTorchAccess sharedManager] disengageTorch];
                    }];
                }
                [self.torchQueue addOperationWithBlock:^{
                    usleep(INTER_FLASH_DELAY_IN_MICROSEC);
                }];
            }
            [self.torchQueue addOperationWithBlock:^{
                usleep(WORD_DELAY_IN_MICROSEC);
            }];
            counter++;
            ongoingSegment += segmentedProcess;
        }
        [self.torchQueue addOperationWithBlock:^{
            [[SSTorchAccess sharedManager] releaseTorch];
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                [self.hudProgress setAlpha:1];
                [self.transmitButton setTransmit];
            }];
        }];
    } else {
        [[SSTorchAccess sharedManager] releaseTorch];
        [self.hudProgress setAlpha:1];
        [self.torchQueue cancelAllOperations];
        [self.transmitButton setTransmit];
    }
}

#pragma mark - 
- (void)updateTextLabelText:(NSString*) text andMorseLabelText: (NSString*)morseChar {
    self.letterText.text = text;
    [self.letterText setNeedsDisplay];
    self.morseText.text = morseChar;
    [self.morseText setNeedsDisplay];
}

#pragma mark - UITextFieldDelegate
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
            [self.transmitButton setDisabled];
            [self.transmitButton setAlpha:.5f];
        } else {
            [self.transmitButton setTransmit];
            self.transmitButton.enabled = YES;
            [self.transmitButton setAlpha:1.f];
        }
    }
}

@end



