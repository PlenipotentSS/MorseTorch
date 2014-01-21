//
//  UIColor+MorseTorch.m
//  Morse Torch
//
//  Created by Stevenson on 1/20/14.
//  Copyright (c) 2014 Steven Stevenson. All rights reserved.
//

#import "UIColor+MorseTorch.h"

@implementation UIColor (MorseTorch)

+(UIColor*) getCancelBgColor {
    return [UIColor colorWithRed:246.f/255.f green:146.f/255.f blue:139.f/255.f alpha:1.0];
}

+(UIColor*) getCancelTintColor {
    return [UIColor colorWithRed:240.f/255.f green:9.f/255.f blue:26.f/255.f alpha:.70];
}


+(UIColor*) getTransmitBgColor {
    return [UIColor colorWithRed:175.f/255.f green:255.f/255.f blue:169.f/255.f alpha:1.0];
}

+(UIColor*) getTransmitTintColor {
    return [UIColor colorWithRed:76.f/255.f green:254.f/255.f blue:22.f/255.f alpha:.70];
}

@end
