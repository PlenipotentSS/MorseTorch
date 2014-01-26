//
//  UIColor+MorseTorch.h
//  Morse Torch
//
//  Created by Stevenson on 1/20/14.
//  Copyright (c) 2014 Steven Stevenson. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIColor (MorseTorch)

//custom color of red for cancel button
+(UIColor*) getCancelBgColor;

//custom color of green for transmit button
+(UIColor*) getTransmitBgColor;

//some random color
+(UIColor*) randomColor;

@end
