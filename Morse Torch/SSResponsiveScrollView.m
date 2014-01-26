//
//  SSResponsiveScrollView.m
//  Morse Torch
//
//  Created by Stevenson on 1/25/14.
//  Copyright (c) 2014 Steven Stevenson. All rights reserved.
//

#import "SSResponsiveScrollView.h"

@implementation SSResponsiveScrollView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.textFields = [[NSArray alloc] init];
    }
    return self;
}

- (BOOL)touchesShouldBegin:(NSSet *)touches withEvent:(UIEvent *)event inContentView:(UIView *)view {
    if ([self.textFields count] > 0 ) {
        [(UITextField*)self.textFields[0] resignFirstResponder];
    }
    return YES;
}

@end
