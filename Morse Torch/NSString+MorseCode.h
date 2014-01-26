//
//  NSString+MorseCode.h
//  Morse Torch
//
//  Created by Stevenson on 1/20/14.
//  Copyright (c) 2014 Steven Stevenson. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (MorseCode)

//gets the symbol for a current letter
+(NSString*) getSymbolFromLetter: (NSString*) letter;

//gets all the symbols in a current string
+(NSArray*) getSymbolsFromString: (NSString*) string;

//validates the current string to allow only A-Z & 0-9
+(NSString*) validateString:(NSString*) string;

//returns the letter for a current mosr word
+(NSString*) letterForMorseWord: (NSString *) symbol;

@end
