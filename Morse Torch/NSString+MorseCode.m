//
//  NSString+MorseCode.m
//  Morse Torch
//
//  Created by Stevenson on 1/20/14.
//  Copyright (c) 2014 Steven Stevenson. All rights reserved.
//

#import "NSString+MorseCode.h"

@implementation NSString (MorseCode)

+(NSString*) getSymbolFromLetter:(NSString *)letter {
    letter = [self validateString:letter];
    if ([letter length] > 0) {
        return [self symbolForLetter:letter];
    }
    return @"";
}

+(NSArray*) getSymbolsFromString:(NSString *)string {
    string = [self validateString:string];
    NSMutableArray *symbols = [NSMutableArray new];
    for (NSUInteger i =0;i<[string length];i++) {
        [symbols addObject:[self symbolForLetter:[string substringWithRange:NSMakeRange(i,1)]]];
    }
    return [NSArray arrayWithArray:symbols];
}

#pragma mark String Valudation
+(NSString*) validateString:(NSString*) string {
    string = [string uppercaseString];
    
    NSError *error;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[^A-Z0-9]" options:NSRegularExpressionCaseInsensitive error:&error];
    string = [regex stringByReplacingMatchesInString:string options:0 range:NSMakeRange(0, [string length]) withTemplate:@""];
    if (!error) {
        return string;
    }
    return @"";
}

#pragma mark Symbol/Letter Retrieval
+(NSString*) symbolForLetter: (NSString*) letter {
    return [[self symbolLetterDictionary] objectForKey:letter];
}

+(NSString*) letterForSymbol: (NSString *) symbol {
    //1->1 map ensures array of length 1
    NSArray *letters = [[self symbolLetterDictionary] allKeysForObject:symbol];
    return letters[0];
}

+(NSDictionary*) symbolLetterDictionary {
    NSDictionary *theDictionary = @{@"A":SYMBOL_FOR_A,
                                    @"B":SYMBOL_FOR_B,
                                    @"C":SYMBOL_FOR_C,
                                    @"D":SYMBOL_FOR_D,
                                    @"E":SYMBOL_FOR_E,
                                    @"F":SYMBOL_FOR_F,
                                    @"G":SYMBOL_FOR_G,
                                    @"H":SYMBOL_FOR_H,
                                    @"I":SYMBOL_FOR_I,
                                    @"J":SYMBOL_FOR_J,
                                    @"K":SYMBOL_FOR_K,
                                    @"L":SYMBOL_FOR_L,
                                    @"M":SYMBOL_FOR_M,
                                    @"N":SYMBOL_FOR_N,
                                    @"O":SYMBOL_FOR_O,
                                    @"P":SYMBOL_FOR_P,
                                    @"Q":SYMBOL_FOR_Q,
                                    @"R":SYMBOL_FOR_R,
                                    @"S":SYMBOL_FOR_S,
                                    @"T":SYMBOL_FOR_T,
                                    @"U":SYMBOL_FOR_U,
                                    @"V":SYMBOL_FOR_V,
                                    @"W":SYMBOL_FOR_W,
                                    @"X":SYMBOL_FOR_X,
                                    @"Y":SYMBOL_FOR_Y,
                                    @"Z":SYMBOL_FOR_Z,
                                    @"0":SYMBOL_FOR_0,
                                    @"1":SYMBOL_FOR_1,
                                    @"2":SYMBOL_FOR_2,
                                    @"3":SYMBOL_FOR_3,
                                    @"4":SYMBOL_FOR_4,
                                    @"5":SYMBOL_FOR_5,
                                    @"6":SYMBOL_FOR_6,
                                    @"7":SYMBOL_FOR_7,
                                    @"8":SYMBOL_FOR_8,
                                    @"9":SYMBOL_FOR_9};
    return theDictionary;
}


@end
