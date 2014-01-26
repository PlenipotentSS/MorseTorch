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

//returns the color between two colors given a percentage of one
-(UIColor*) getNextColor:(CGFloat) progress {
    CGFloat r1,g1,b1,a1;
    [[UIColor getTransmitBgColor] getRed:&r1 green:&g1 blue:&b1 alpha:&a1];
    
    CGFloat r2,g2,b2,a2;
    [[UIColor getCancelBgColor] getRed:&r2 green:&g2 blue:&b2 alpha:&a2];
    
    CGFloat r,g,b,a;
    r = r2-progress*(r2-r1);
    g = g2-progress*(g2-g1);
    b = b2-progress*(b2-b1);
    a = a2-progress*(a2-a1);
    
    return [UIColor colorWithRed:r green:g blue:b alpha:a];
}

@end
