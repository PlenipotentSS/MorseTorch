//
//  SSProgressViewRingGradient.m
//  Morse Torch
//
//  Created by Stevenson on 1/22/14.
//  Copyright (c) 2014 Steven Stevenson. All rights reserved.
//

#import "SSProgressViewRingGradient.h"
#import "UIColor+MorseTorch.h"

@implementation SSProgressViewRingGradient

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

-(void)setProgress:(CGFloat)progress animated:(BOOL)animated {
    [super setProgress:progress animated:animated];
    UIColor *thisProgressColor =[self getNextColor:progress];
    [super setPrimaryColor:thisProgressColor];
    [super setSecondaryColor:thisProgressColor];
}

-(UIColor*) getNextColor:(CGFloat) progress {
    return [UIColor colorWithRed:0 green:progress blue:1.f-progress alpha:1.f];
}

@end
