//
//  ViewController.m
//  MyKidCheckin
//
//  Created by Rui Yang on 4/6/15.
//  Copyright (c) 2015 Rui Yang. All rights reserved.
//

#import "ViewController.h"
#import "MyParentTableViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    NSInteger mode = [[NSUserDefaults standardUserDefaults] integerForKey:@"mode"];
    if (mode) {
        if (mode == 1) {
            [self asParent];
        } else if (mode == 2) {
            [self asChild];
        }
        return;
    }
    // Do any additional setup after loading the view, typically from a nib.
    UIActionSheet *popup = [[UIActionSheet alloc] initWithTitle:@"Select mode:" delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:
                            @"Login as Parent",
                            @"Login as Child",
                            nil];
    popup.tag = 1;
    [popup showInView:[UIApplication sharedApplication].keyWindow];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) asParent {
    [[NSUserDefaults standardUserDefaults] setInteger:1 forKey:@"mode"];
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    MyParentTableViewController *vc = (MyParentTableViewController*)[storyboard instantiateViewControllerWithIdentifier:@"myParentViewController"];

    UINavigationController *vcNav =[[UINavigationController alloc] initWithRootViewController:vc];

    [self presentViewController:vcNav animated:YES completion:nil];
}

- (void) asChild {
    [[NSUserDefaults standardUserDefaults] setInteger:2 forKey:@"mode"];
}

- (void)actionSheet:(UIActionSheet *)popup clickedButtonAtIndex:(NSInteger)buttonIndex {
    
    switch (popup.tag) {
        case 1: {
            switch (buttonIndex) {
                case 0:
                    NSLog(@"this is a selection 0");
                    [self asParent];
                    break;
                case 1:
                    NSLog(@"this is selction 1");
                    [self asChild];
                    break;

                    break;
                default:
                    break;
            }
            break;
        }
        default:
            break;
    }
}

@end
