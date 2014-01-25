//
//  SSReceiveViewController.h
//  Morse Torch
//
//  Created by Stevenson on 1/22/14.
//  Copyright (c) 2014 Steven Stevenson. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SSBrightnessDetector.h"

@interface SSReceiveViewController : UIViewController

@property (nonatomic) NSUInteger pageIndex;
@property (nonatomic) SSBrightnessDetector *brightnessDetector;
@end
