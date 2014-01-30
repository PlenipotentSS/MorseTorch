//
//  SSTorchAccess.h
//  Morse Torch
//
//  Created by Stevenson on 1/22/14.
//  Copyright (c) 2014 Steven Stevenson. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SSTorchAccess : NSObject

//shared Manager for this singleton
+(SSTorchAccess*) sharedManager;

//required to use the torch
-(void) takeTorch;

//required to release the torch after us
-(void) releaseTorch;

//returns whether the user is accessing the torch
-(BOOL) isTransmitting;

//turns the torch on
-(void) engageTorch;

//turns the torch off
-(void) disengageTorch;


@end
