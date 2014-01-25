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

@import AVFoundation;

@interface InputViewController () <UITextFieldDelegate>
@property (weak, nonatomic) IBOutlet UITextField *inputField;
@property (weak, nonatomic) IBOutlet SSMorseButton *transmitButton;
@property (weak, nonatomic) IBOutlet UILabel *morseText;
@property (weak, nonatomic) IBOutlet UILabel *letterText;
@property (nonatomic) NSOperationQueue *torchQueue;
@property (nonatomic) SSProgressViewRingGradient *hudProgress;

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
    // Do any additional setup after loading the view.
}

#pragma mark Setup Views
-(void) setup {
    self.hudProgress = [[SSProgressViewRingGradient alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    self.hudProgress.center = CGPointMake(CGRectGetMidX(self.view.frame), CGRectGetMidY(self.view.frame)+140);
    self.hudProgress.showPercentage = NO;
    
    [self.view addSubview:self.hudProgress];
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
                    usleep(LETTER_DELAY_IN_MICROSEC);
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



