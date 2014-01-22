//
//  SSNSOperation.m
//  Morse Torch
//
//  Created by Stevenson on 1/21/14.
//  Copyright (c) 2014 Steven Stevenson. All rights reserved.
//

#import "SSNSOperation.h"
@interface SSNSOperation()

@end

@implementation SSNSOperation

-(id) initWithMorseArray: (NSArray*) morseArray andString: (NSString*)inputText {
    self = [super init];
    if (self) {
        _morseArray = morseArray;
        _inputText = inputText;
        
        self.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    return self;
}

-(void) addTextLabel: (UILabel*) textLabel andMorseLabel: (UILabel*) morseLabel {
    self.textLabel = textLabel;
    self.morseLabel = morseLabel;
}

-(void)main {
    NSUInteger counter = 0;
    unichar charString;
    for (NSString* code in self.morseArray) {
        if (self.isCancelled) {
            break;
        }
        charString = [self.inputText characterAtIndex:counter] ;
        counter++;
        for (NSUInteger i=0;i<[code length];i++) {
            NSString *dotOrDash = [code substringWithRange:NSMakeRange(i, 1)];
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                [_delegate updateTextLabelText:[NSString stringWithFormat:@"%c",charString] andMorseLabelText:code];
            }];
            if ([dotOrDash isEqualToString:@"."]) {
                [self engageTorch];
                usleep(DOT_IN_MICROSEC);
                [self disengageTorch];
            } else if ([dotOrDash isEqualToString:@"_"]) {
                [self engageTorch];
                usleep(DASH_IN_MICROSEC);
                [self disengageTorch];
            }
            usleep(LETTER_DELAY_IN_MICROSEC);
            if (self.isCancelled) {
                break;
            }
        }
        usleep(WORD_DELAY_IN_MICROSEC);
    };
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

@end
