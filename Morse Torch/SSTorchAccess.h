//
//  SSTorchAccess.h
//  Morse Torch
//
//  Created by Stevenson on 1/22/14.
//  Copyright (c) 2014 Steven Stevenson. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SSTorchAccess : NSObject


+(SSTorchAccess*) sharedManager;

-(void) takeTorch;
-(void) releaseTorch;
-(BOOL) isTransmitting;

-(void) engageTorch;
-(void) disengageTorch;


@end
