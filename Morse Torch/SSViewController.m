//
//  SSViewController.m
//  Morse Torch
//
//  Created by Stevenson on 1/22/14.
//  Copyright (c) 2014 Steven Stevenson. All rights reserved.
//

#import "SSViewController.h"
#import "InputViewController.h"
#import "SSReceiveViewController.h"
#import "SSTorchAccess.h"

@interface SSViewController () <UIPageViewControllerDataSource>
@property (strong, nonatomic) UIPageViewController *pageViewController;

@end

@implementation SSViewController

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
    // Create page view controller
    self.pageViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"PageViewController"];
    self.pageViewController.dataSource = self;
    
    InputViewController *startingViewController = (InputViewController*)[self viewControllerAtIndex:0];
    NSArray *viewControllers = @[startingViewController];
    [self.pageViewController setViewControllers:viewControllers direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:nil];
    
    // Change the size of page view controller
    self.pageViewController.view.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height - 30);
    
    [self addChildViewController:_pageViewController];
    [self.view addSubview:_pageViewController.view];
    [self.pageViewController didMoveToParentViewController:self];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Page View Controller Data Source

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController
{
    NSUInteger index = 0;
    if ([viewController isKindOfClass:[InputViewController class]]) {
        index = ((InputViewController*) viewController).pageIndex;
    } else {
        index = ((SSReceiveViewController*) viewController).pageIndex;
    }
    if (index == 0) {
        return nil;
    }
    
    index--;
    return [self viewControllerAtIndex:index];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController
{
    NSUInteger index = 0;
    if ([viewController isKindOfClass:[InputViewController class]]) {
        index = ((InputViewController*) viewController).pageIndex;
    } else {
        index = ((SSReceiveViewController*) viewController).pageIndex;
    }
    if (index == 1) {
        return nil;
    }
    
    index++;
    return [self viewControllerAtIndex:index];
}

- (UIViewController *)viewControllerAtIndex:(NSUInteger)index
{
    if (index==0) {
        InputViewController *pageContentViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"transmitVC"];
        pageContentViewController.pageIndex = index;
        return pageContentViewController;
    } else if (index==1) {
        SSReceiveViewController *pageContentViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"receiveVC"];
        pageContentViewController.pageIndex = index;
        return pageContentViewController;
    }
    
    return nil;
}

- (NSInteger)presentationCountForPageViewController:(UIPageViewController *)pageViewController
{
    return 2;
}

- (NSInteger)presentationIndexForPageViewController:(UIPageViewController *)pageViewController
{
    return 0;
}

@end
