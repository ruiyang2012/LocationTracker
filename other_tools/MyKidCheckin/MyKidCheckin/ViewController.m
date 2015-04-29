//
//  ViewController.m
//  MyKidCheckin
//
//  Created by Rui Yang on 4/6/15.
//  Copyright (c) 2015 Rui Yang. All rights reserved.
//

#import "ViewController.h"
#import "MyParentTableViewController.h"
#import <MapKit/MapKit.h>
#import "ChildQrController.h"
#import "ChildCheckInController.h"
#import "MyApi.h"

@interface ViewController () <MyParentTableViewControllerDelegate, CLLocationManagerDelegate, ChildQrControllerDelegate> {
    CLLocationManager * locationManager;
    CLLocation * currentLocation;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    locationManager = [[CLLocationManager alloc] init];
    locationManager.delegate = self;
    locationManager.distanceFilter = 50.0f;
    locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
    [locationManager requestWhenInUseAuthorization];
    
    [locationManager startUpdatingLocation];
    //[locationManager startMonitoringSignificantLocationChanges];
    //[self RememberLocation:locationManager.location.coordinate];
}

- (void) RememberLocation:(CLLocationCoordinate2D) loc {
    NSNumber *lat = [NSNumber numberWithDouble:loc.latitude];
    NSNumber *lng = [NSNumber numberWithDouble:loc.longitude];
    NSDictionary *userLocation=@{@"lat":lat,@"lng":lng};
    [[NSUserDefaults standardUserDefaults] setObject:userLocation forKey:@"userLocation"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

-(void) onQrDone:(NSString *)childId {
    dispatch_async(dispatch_get_main_queue(), ^(void){
        [self asChild];
    });
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    currentLocation = [locations objectAtIndex:0];
    [self RememberLocation:currentLocation.coordinate];
}


- (void) onReset {
    NSInteger mode = [[NSUserDefaults standardUserDefaults] integerForKey:@"mode"];

    if (mode) {
        if (mode == 1) {
            [self asParent];
        } else if (mode == 2) {
            [self asChild];
        }
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^(void){
        //Run UI Updates
        // Do any additional setup after loading the view, typically from a nib.
        UIActionSheet *popup = [[UIActionSheet alloc] initWithTitle:@"Select mode:" delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:
                                @"Login as Parent",
                                @"Login as Child",
                                nil];
        popup.tag = 1;
        [popup showInView:[UIApplication sharedApplication].keyWindow];
    });

}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self onReset];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) asParent {
    [[NSUserDefaults standardUserDefaults] setInteger:1 forKey:@"mode"];
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    MyParentTableViewController *vc = (MyParentTableViewController*)[storyboard instantiateViewControllerWithIdentifier:@"myParentViewController"];
    vc.delegate = self;

    UINavigationController *vcNav =[[UINavigationController alloc] initWithRootViewController:vc];

    [self presentViewController:vcNav animated:YES completion:nil];
}

- (void) asChild {
    [[NSUserDefaults standardUserDefaults] setInteger:2 forKey:@"mode"];
    NSString * childId = [[NSUserDefaults standardUserDefaults] stringForKey:@"childId"];
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    UIViewController * vc = nil;

    if (childId) {
        vc = [storyboard instantiateViewControllerWithIdentifier:@"childCheckinVC"];
        if (currentLocation) {
            NSTimeInterval ts = [[NSDate date] timeIntervalSince1970];
            NSString * lat = [NSString stringWithFormat:@"%f", currentLocation.coordinate.latitude];
            NSString * lng = [NSString stringWithFormat:@"%f", currentLocation.coordinate.longitude];
            [MyApi api:@"check_ins" param:@{ @"cid" : childId,
                                             @"lat" : lat,
                                             @"lng" : lng,
                                             @"ts"  : [NSNumber numberWithDouble:ts],
                                             @"addr" : @"" }];
        }
    } else {
        vc = [storyboard instantiateViewControllerWithIdentifier:@"childQrCodeVC"];
    }
    UINavigationController *vcNav =[[UINavigationController alloc] initWithRootViewController:vc];
    
    [self presentViewController:vcNav animated:YES completion:nil];
}

- (void)actionSheet:(UIActionSheet *)popup clickedButtonAtIndex:(NSInteger)buttonIndex {
    
    switch (popup.tag) {
        case 1: {
            [popup dismissWithClickedButtonIndex:buttonIndex animated:YES];
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
