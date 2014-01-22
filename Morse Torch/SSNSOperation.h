//
//  SSNSOperation.h
//  Morse Torch
//
//  Created by Stevenson on 1/21/14.
//  Copyright (c) 2014 Steven Stevenson. All rights reserved.
//

#import <Foundation/Foundation.h>
@import AVFoundation;

@protocol SSNOperationDelegate <NSObject>
- (void)updateTextLabelText:(NSString*) text andMorseLabelText: (NSString*)morseChar;
@end


@interface SSNSOperation : NSOperation

@property (nonatomic,weak) id<SSNOperationDelegate> delegate;
-(id) initWithMorseArray: (NSArray*) morseArray andString: (NSString*)inputText;

@property (atomic) NSArray *morseArray;
@property (atomic) NSString *inputText;
@property (weak,atomic) UILabel *textLabel;
@property (weak,atomic) UILabel *morseLabel;
@property (strong) AVCaptureDevice *device;

@end
