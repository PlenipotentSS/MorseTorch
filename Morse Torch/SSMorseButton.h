//
//  SSMorseButton.h
//  Morse Torch
//
//  Created by Stevenson on 1/24/14.
//  Copyright (c) 2014 Steven Stevenson. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SSMorseButton : UIButton

//sets the current button color to mark to cancel
-(void) setCancel;

//sets the current button color to mark to transmit
-(void) setTransmit;

//sets the current button color to mark to receive
-(void) setReceive;

//sets the current button color to mark as disabled
-(void) setDisabled;

@end
