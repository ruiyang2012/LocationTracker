//
//  ChildCheckInController.m
//  MyKidCheckin
//
//  Created by Rui Yang on 4/22/15.
//  Copyright (c) 2015 Rui Yang. All rights reserved.
//

#import "ChildCheckInController.h"
#import <MapKit/MapKit.h>
#import "MyApi.h"

@interface ChildCheckInController () <MKMapViewDelegate>

@property (weak, nonatomic) IBOutlet MKMapView *myMapView;

@end

@implementation ChildCheckInController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.myMapView.delegate = self;
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    //[self zoomToUserLocation:self.myMapView.userLocation];
    NSDictionary * userLoc = [[NSUserDefaults standardUserDefaults] objectForKey:@"userLocation"];
    if (userLoc) {
        NSNumber * lat = [userLoc objectForKey:@"lat"];
        NSNumber * lng = [userLoc objectForKey:@"lng"];
        [self zoomToUserLocation:CLLocationCoordinate2DMake([lat doubleValue], [lng doubleValue])];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)onCheckIn:(id)sender {
    NSDictionary * userLoc = [[NSUserDefaults standardUserDefaults] objectForKey:@"userLocation"];
    if (userLoc) {
        NSNumber * lat = [userLoc objectForKey:@"lat"];
        NSNumber * lng = [userLoc objectForKey:@"lng"];
        NSString * childId = [[NSUserDefaults standardUserDefaults] stringForKey:@"childId"];
        [MyApi api:@"check_ins" param:@{ @"cid" : childId,
                                         @"lat" : [lat stringValue],
                                         @"lng" : [lng stringValue],
                                         @"addr" : @"" }];
    } else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No User Location info!"
                                                        message:@"Please check if user location is enabled!"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }

}


- (void)zoomToUserLocation:(CLLocationCoordinate2D)userLocation
{

    MKCoordinateRegion region;
    region.center = userLocation;
    region.span = MKCoordinateSpanMake(0.02, 0.02); //Zoom distance
    region = [self.myMapView regionThatFits:region];
    [self.myMapView setRegion:region animated:YES];
}

- (void)mapView:(MKMapView *)theMapView didUpdateToUserLocation:(MKUserLocation *)location
{
    [self zoomToUserLocation:location.location.coordinate];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
