//
//  SSMorseButton.m
//  Morse Torch
//
//  Created by Stevenson on 1/24/14.
//  Copyright (c) 2014 Steven Stevenson. All rights reserved.
//

#import "SSMorseButton.h"
#import "UIColor+MorseTorch.h"

@implementation SSMorseButton

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

#pragma mark Button Methods
-(void) setCancel {
    [self setTitle:@"Cancel" forState:UIControlStateNormal];
    [self setBackgroundColor:[UIColor getCancelBgColor]];
}

-(void) setTransmit {
    [self setTitle:@"Transmit" forState:UIControlStateNormal];
    [self setBackgroundColor:[UIColor getTransmitBgColor]];
}

-(void) setReceive {
    [self setTitle:@"Receive" forState:UIControlStateNormal];
    [self setBackgroundColor:[UIColor getTransmitBgColor]];
}


-(void) setDisabled {
    [self setBackgroundColor:[UIColor groupTableViewBackgroundColor]];
    self.enabled = NO;
}

@end
