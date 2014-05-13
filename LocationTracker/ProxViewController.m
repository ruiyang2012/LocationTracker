//
//  ProxViewController.m
//  LocationTracker
//
//  Created by rui yang on 5/11/14.
//  Copyright (c) 2014 Linc. All rights reserved.
//

#import "ProxViewController.h"
#import "OfflineManager.h"
#import "ProxLocationManager.h"

@interface ProxViewController () {
  OfflineManager * offlineMg;
  ProxLocationManager * locMg;
  int radius;
}

@end

@implementation ProxViewController

@synthesize mapView;

- (void)viewDidLoad
{
    [super viewDidLoad];
  radius = 4800;
	// Do any additional setup after loading the view, typically from a nib.
  self.mapView.delegate = self;
  offlineMg = [[OfflineManager alloc] init];
  locMg = [[ProxLocationManager alloc] initWithOfflineManager:offlineMg];
  NSNotificationCenter *notCenter = [NSNotificationCenter defaultCenter];
  [notCenter addObserver:self selector:@selector(enteredForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
  [notCenter addObserver:self selector:@selector(locationChange:) name:@"locationChange" object:nil];
  [NSTimer scheduledTimerWithTimeInterval:60*5 target:self selector:@selector(updateMap) userInfo:nil repeats:YES];
}

- (void)locationChange:(NSNotification*) notify {
  id dict = notify.object;
  if ([dict isKindOfClass:[NSDictionary class]]) {
    CLLocation* loc = [dict objectForKey:@"newLocation"];
    if ([loc speed] < 5) [self updateMap];
  }
}

- (void)enteredForeground:(NSNotification*) notify {
  NSLog(@"Enter foreground");
  [self updateMap];
}

- (void) updateMap{
  [self.mapView removeAnnotations:self.mapView.annotations];
    // iterate all histogram:
  NSArray * todayLocations = [offlineMg getTodayLocations];
  MKPointAnnotation *point = nil;
  CLLocation * lastLocation = nil;
  CLLocation * curLoc = nil;
  for (id locDic in todayLocations) {
    double lat = [[locDic objectForKey:@"lat"] doubleValue];
    double lon = [[locDic objectForKey:@"lon"] doubleValue];
    int stay = [[locDic objectForKey:@"duration"] intValue] / 60;
    point = [[MKPointAnnotation alloc] init];
    lastLocation = curLoc;
    curLoc = [[CLLocation alloc] initWithLatitude:lat longitude:lon];
    point.coordinate = curLoc.coordinate;
    point.title = [locDic objectForKey:@"name"];
    point.subtitle = [NSString stringWithFormat:@"stay at %@ for %d mins", [locDic objectForKey:@"street"], stay];
    
    [self.mapView addAnnotation:point];

  }
  int latestDistance = [lastLocation distanceFromLocation:curLoc];
  if (latestDistance > radius / 1.5 && latestDistance < 1600 * 20) {
    radius = latestDistance * 1.5;
    NSLog(@"adjusted radius is %d", radius);
  }
  if (point) {
    [self centerAtLocation:point.coordinate];
  }
  

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) centerAtLocation:(CLLocationCoordinate2D) position {
  MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(position, radius, radius);
  [self.mapView setRegion:[self.mapView regionThatFits:region] animated:YES];
}

- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation
{
  [self centerAtLocation:userLocation.coordinate];

}

- (MKAnnotationView *)mapView:(MKMapView *)theMapView viewForAnnotation:(id <MKAnnotation>)annotation
{
  static NSString *SFAnnotationIdentifier = @"SFAnnotationIdentifier";
  MKPinAnnotationView *pinView =
  (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:SFAnnotationIdentifier];
  NSLog(@"annotation");
  return pinView;
}

@end
