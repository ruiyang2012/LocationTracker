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

#import "LincAnnotation.h"

@interface ProxViewController () {
  OfflineManager * offlineMg;
  ProxLocationManager * locMg;
  int radius;
  BOOL isCenteredOnce;
  NSMutableDictionary * pins;
  BOOL forceAddMarker;
}

@end

@implementation ProxViewController

@synthesize mapView;

- (void)viewDidLoad
{
    [super viewDidLoad];
  radius = 4800;
  isCenteredOnce = NO;
  forceAddMarker = NO;

  UIBarButtonItem * flipBtn = [[UIBarButtonItem alloc] initWithTitle:@"All" style:UIBarButtonItemStyleBordered target:self action:@selector(toggleToday:)];
  self.navigationItem.rightBarButtonItem = flipBtn;
  pins = [[NSMutableDictionary alloc] init];
	// Do any additional setup after loading the view, typically from a nib.
  self.mapView.delegate = self;
  offlineMg = [[OfflineManager alloc] init];
  locMg = [[ProxLocationManager alloc] initWithOfflineManager:offlineMg];
  NSNotificationCenter *notCenter = [NSNotificationCenter defaultCenter];
  [notCenter addObserver:self selector:@selector(enteredForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
  [notCenter addObserver:self selector:@selector(locationChange:) name:@"locationChange" object:nil];
  [NSTimer scheduledTimerWithTimeInterval:60*5 target:self selector:@selector(updateMap) userInfo:nil repeats:YES];
  
  
}

- (IBAction) toggleToday:(UIBarButtonItem*)sender {
  NSLog(@"Button Toggled");
  [self.mapView removeAnnotations:[self.mapView annotations]];
  forceAddMarker = YES;
  if ([sender.title isEqualToString:@"All"]) {
    [sender setTitle:@"Today"];
    [self updateMapFromTopLocations];
  } else {
    [sender setTitle:@"All"];
    [self updateMap];
  }
  forceAddMarker = NO;
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


- (CLLocation*) addOneMarker:(NSDictionary*) locDic {
  NSString* bucket = [locDic objectForKey:@"bucket"];

  LincAnnotation * pin =[pins objectForKey:bucket];
  if (pin) {
    if (forceAddMarker) [self.mapView addAnnotation:pin];
    pin.locationDict = locDic;
    return pin.curLoc;
  }
  
  LincAnnotation * point = [[LincAnnotation alloc] init];
  point.bucket = bucket;
  point.locationDict = locDic;
  point.offlineMg = offlineMg;
  [point updateWithMapView:self.mapView];
  [pins setObject:point forKey:bucket];

  return point.curLoc;
}

- (void) addOneMarkerFromBucket:(NSString*) bucket {
  LincAnnotation * point = [[LincAnnotation alloc] init];
  point.bucket = bucket;
  point.offlineMg = offlineMg;
  [point updateWithMapView:self.mapView];
  [pins setObject:point forKey:bucket];
}

- (void) updateMapFromTopLocations {
  NSArray * allLocs = [offlineMg getLongestStayOfAllTime:300 limit:100];
  for (id bucket in allLocs) {
    [self addOneMarkerFromBucket:bucket];
  }
}

- (void) updateMap{
  
    // iterate all histogram:
  NSArray * todayLocations = [offlineMg getTodayLocations];

  CLLocation * lastLocation = nil;
  CLLocation * curLoc = nil;
  for (id locDic in todayLocations) {
    lastLocation = curLoc;
    curLoc = [self addOneMarker:locDic];
  }
  int latestDistance = [lastLocation distanceFromLocation:curLoc];
  if (latestDistance > radius / 1.5 && latestDistance < 1600 * 20) {
    radius = latestDistance * 1.5;
    NSLog(@"adjusted radius is %d", radius);
  }
  if (curLoc) { [self centerAtLocation:curLoc.coordinate]; }
  

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
  if (!isCenteredOnce) {
    [self centerAtLocation:userLocation.coordinate];
  }
  isCenteredOnce = YES;

}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view {
  if ([view.annotation isKindOfClass:[LincAnnotation class]]) {
    LincAnnotation * anno = (LincAnnotation*) view.annotation;
      //NSLog(@"did click view %@", anno);
    [anno showAddressConfirm:self.mapView];
  }
}

@end
