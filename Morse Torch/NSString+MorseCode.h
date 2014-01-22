//
//  NSString+MorseCode.h
//  Morse Torch
//
//  Created by Stevenson on 1/20/14.
//  Copyright (c) 2014 Steven Stevenson. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (MorseCode)

+(NSString*) getSymbolFromLetter: (NSString*) letter;

+(NSArray*) getSymbolsFromString: (NSString*) string;

+(NSString*) validateString:(NSString*) string;

@end
