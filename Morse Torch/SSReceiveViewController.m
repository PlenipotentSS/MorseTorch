//
//  SSReceiveViewController.m
//  Morse Torch
//
//  Created by Stevenson on 1/22/14.
//  Copyright (c) 2014 Steven Stevenson. All rights reserved.
//

#import "SSReceiveViewController.h"
#import "SSTorchAccess.h"

@interface SSReceiveViewController ()

@end

@implementation SSReceiveViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if ([[SSTorchAccess sharedManager] isTransmitting] ){
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Transmitting" message:@"Please Wait While the current Code is Transmitting" delegate:self cancelButtonTitle:@"Okay" otherButtonTitles:nil];
        [alertView show];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
