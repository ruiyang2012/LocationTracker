//
//  ProxLocationManager.m
//  clientApiLib
//
//  Created by rui yang on 4/22/14.
//  Copyright (c) 2014 rui yang. All rights reserved.
//
#import <CoreLocation/CoreLocation.h>

#import "ProxLocationManager.h"
#import "OfflineManager.h"
#import "ProxUtils.h"

static const int MAX_WALKING_SPEED = 3; // 3 meters/s
static const NSString* GAPI_BASE_URL = @"https://maps.googleapis.com/maps/api/geocode/json?sensor=false&location_type=ROOFTOP&result_type=street_address&key=AIzaSyDk2hk_TQDAUus5uG9GZc-0EfypzMMe__0&latlng=";

@interface ProxLocationManager() <CLLocationManagerDelegate> {
  OfflineManager * offlineMg;
  CLGeocoder * geocoder;
  CLLocation * lastLocation;
  NSTimeInterval lastLocationUpdate;
  CLLocationManager * locMan;
  CLLocation * curLocation;
  CLLocation * homeLocation;
  NSMutableArray * locLogs;
  int elapse;
  CLRegion * lastRegion;
  NSURLSession * session;
  NSTimeInterval regionEnterTime;
}
@end

@implementation ProxLocationManager

- (id) initWithOfflineManager: (id) offlineManger {
  self = [super init];
  offlineMg = offlineManger;
  geocoder = [[CLGeocoder alloc] init];
  regionEnterTime = lastLocationUpdate = [[NSDate date] timeIntervalSince1970];
  locLogs = [[NSMutableArray alloc] init];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(netStatus:) name:@"ProxOfflineStatusChange" object:nil];
  [self setupLocationManager];
  NSString * homeLocStr = [[NSUserDefaults standardUserDefaults] objectForKey:@"homeLocation"];
  homeLocation = [self locationStrToLoc:homeLocStr sep:@","];
  if (![[NSUserDefaults standardUserDefaults] doubleForKey:@"firstLaunch"]) {
    [[NSUserDefaults standardUserDefaults] setDouble:lastLocationUpdate forKey:@"firstLaunch"];
  }
  session = [NSURLSession sharedSession];
  [self performSelector:@selector(netStatus:) withObject:nil afterDelay:0];
  return self;
}

- (NSArray*) getLogs {
  return locLogs;
}

- (void) resetLogs {
  [locLogs removeAllObjects];
}

- (void) setupLocationManager {
  if (locMan != nil) return;
  locMan = [[CLLocationManager alloc] init];
  locMan.delegate = self;
  locMan.distanceFilter = kCLDistanceFilterNone;
  locMan.desiredAccuracy = kCLLocationAccuracyBest;
  [locMan startMonitoringSignificantLocationChanges];
    //[locMan startUpdatingLocation];
}

- (CLLocation *) locationStrToLoc:(NSString *) locStr sep:(NSString*)sep{
  NSArray * arr = [locStr componentsSeparatedByString:sep];
  if ([arr count] >= 2) {
      double lat = [arr[0] doubleValue];
      double lon = [arr[1] doubleValue];
      if (lat ==0 || lon == 0) return nil;
      return [[CLLocation alloc] initWithLatitude:lat longitude:lon];
  }
 
  return nil;
}

- (NSString*) locationToLatLonStr:(CLLocation *) loc {
  return [NSString stringWithFormat:@"%f,%f", loc.coordinate.latitude, loc.coordinate.longitude];
}

- (NSString*) placemarkToStr:(CLPlacemark*) pl {
  return [NSString stringWithFormat:@"%f|%f|%@|%@|%@|%@|%@|%@", pl.location.coordinate.latitude,
            pl.location.coordinate.longitude, pl.name, pl.thoroughfare, pl.locality, pl.administrativeArea,
            pl.ISOcountryCode, pl.postalCode];
}

- (void) netStatus:(NSNotification *)notify {
  if ([offlineMg isOffline]) return;
    // geo look up all raw_data again.
  NSArray * arr = [offlineMg getAllUnconfirmedGeo];
  for (id item in arr) {
    NSArray * locArr = [item[0] componentsSeparatedByString:@","];
    NSNumber * time = item[1];
    CLLocation * loc = [[CLLocation alloc] initWithLatitude:[locArr[0] doubleValue] longitude:[locArr[1] doubleValue]];
    [self lookupLocation:loc updateTime:time];
  }
}

- (void) locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region {
  NSLog(@"region entered!");
  regionEnterTime = [[NSDate date] timeIntervalSince1970];

}


- (void) dispatchLocationChange:(CLLocation*) oldLocation to:(CLLocation*)newLocation duration:(int) duration {
  CLLocation * old = oldLocation ? oldLocation : newLocation;
  NSDictionary * dict = [[NSDictionary alloc] initWithObjectsAndKeys:[newLocation copy], @"newLocation",
                         [old copy], @"oldLocation",[NSNumber numberWithInt:duration], @"elapse", nil];
  [[NSNotificationCenter defaultCenter] postNotificationName:@"locationChange" object:dict];
}

- (void) locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region {
  NSLog(@"region exit!");
  if ([region isEqual:lastRegion]) return;
  if (![region isKindOfClass:[CLCircularRegion class]]) return;
  CLCircularRegion * clRegion = (CLCircularRegion*) region;
  double duration = [[NSDate date] timeIntervalSince1970] - regionEnterTime;

  CLLocation * cl = [[CLLocation alloc] initWithLatitude:clRegion.center.latitude longitude:clRegion.center.longitude];
  lastRegion = region;
  [self dispatchLocationChange:cl to:curLocation duration:duration];

}

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation {
    //NSLog(@"Speed is %f -- %f", oldLocation.speed, newLocation.speed);

  curLocation = newLocation;
  NSTimeInterval newTime = [[NSDate date] timeIntervalSince1970];
  elapse = (int) (newTime - lastLocationUpdate);

  NSString * locLog = [NSString stringWithFormat:@"%f,%f,%f",  newTime,
                       curLocation.coordinate.latitude, curLocation.coordinate.longitude];
  
  [locLogs addObject:locLog];
    //NSLog(@"New lat long: lat%f - lon%f", curLocation.coordinate.latitude, curLocation.coordinate.longitude);
    //if ([oldLocation speed] < MAX_WALKING_SPEED && [newLocation speed] < MAX_WALKING_SPEED) {
  [self performSelectorInBackground:@selector(onLocUpd:) withObject:newLocation];
    //}
  [self dispatchLocationChange:oldLocation to:newLocation duration:elapse];

  lastLocationUpdate = newTime;
}

-(id) getCurLoc {
  return curLocation;
}

- (void) onLocUpd:(CLLocation*) loc {
  
  [self addLocation:loc];
    // look up using google place api and four square api here:
  double firstLaunch = [[NSUserDefaults standardUserDefaults] doubleForKey:@"firstLaunch"];
  NSDate * firstLaunchDate = [NSDate dateWithTimeIntervalSince1970:firstLaunch];
  NSInteger daysElapse = [ProxUtils daysBetween:firstLaunchDate to:[NSDate date]];
  if (daysElapse > 0) {
    NSString * homeStr = [offlineMg getLongestOvernightLocation];
    if (homeStr) [[NSUserDefaults standardUserDefaults] setObject:homeStr forKey:@"homeLocation"];
    homeLocation = [self locationStrToLoc:homeStr sep:@","];
  }
  
}

- (void) addLocation:(id) loc {
  if (offlineMg == nil) return;
  
  NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
  CLLocation * curLoc = (CLLocation *) loc;
  NSString * locStr = [self locationToLatLonStr:curLoc];
  NSNumber * nowNum = [NSNumber numberWithLong:now];
  NSNumber * speed = [NSNumber numberWithInt:curLoc.speed];
  [offlineMg setLoc:locStr type:@"raw_data" time:nowNum speed:speed];
  if (![offlineMg isOffline] && curLoc.speed < MAX_WALKING_SPEED) {
    [self lookupLocation:loc updateTime:nowNum];
  }
  [offlineMg calDeltaInTimeSeries];

  lastLocation = loc;
}

- (void) gapiLookup:(CLLocation*) loc updateTime:(NSNumber*) updTime {
  NSString * gapi = [NSString stringWithFormat:@"%@%f,%f", GAPI_BASE_URL, loc.coordinate.latitude, loc.coordinate.longitude];
  NSURL * url = [NSURL URLWithString:gapi];
  [[session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
    if (error) {
        // nslog
      return;
    }
    NSError * jsonError = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (!json) return;
    NSArray * array = json[@"results"];
    NSDictionary * addr = [array firstObject];
    if (!addr) return;
    NSString * lat = [addr[@"geometry"][@"location"][@"lat"] stringValue];
    NSString * lon = [addr[@"geometry"][@"location"][@"lng"] stringValue];
    NSArray * a = [addr[@"formatted_address"] componentsSeparatedByString:@", "];
    if ([a count] != 4) return;
    NSArray * stateZip = [a[2] componentsSeparatedByString:@" "];
    NSArray * locArr = @[lat, lon, a[0], a[0], a[1], stateZip[0], a[3], stateZip[1]];
    NSString * locStr = [locArr componentsJoinedByString:@"|"];
    [offlineMg updateTimeSeriesType:@"raw_data_confirmed" key:[self locationToLatLonStr:loc]];
    NSNumber * speed = [NSNumber numberWithInt:loc.speed];
    [offlineMg setLoc:locStr type:@"apple_map" time:updTime speed:speed];
    [offlineMg calDeltaInTimeSeries];
  }] resume];
  
}

- (void) lookupLocation:(CLLocation *) loc updateTime:(NSNumber*) updTime {

  [geocoder reverseGeocodeLocation:loc completionHandler:^(NSArray *placemarks, NSError *error) {
    if (error || [placemarks count] ==0) {
      NSLog(@"location lookup error: %@ or no place", error);
      [self gapiLookup:loc updateTime:updTime];
      return;
    }
    [offlineMg updateTimeSeriesType:@"raw_data_confirmed" key:[self locationToLatLonStr:loc]];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"geoLookup" object:placemarks];
    for (CLPlacemark * pl in placemarks ) {
      NSNumber * speed = [NSNumber numberWithInt:loc.speed];
      [offlineMg setLoc:[self placemarkToStr:pl] type:@"apple_map" time:updTime speed:speed];
    }
    [offlineMg calDeltaInTimeSeries];
  }];
}

- (BOOL) isCloseToHome {
  if (homeLocation != nil && curLocation != nil) {
      // if near 50 meters of preset home address.
    return [homeLocation distanceFromLocation:curLocation] < 50;
  }
  double now = [[NSDate date] timeIntervalSince1970];
  double today = [[ProxUtils getToday] timeIntervalSince1970];
  if (now - today > 20 * 3600 && curLocation && !homeLocation) {
    return YES;
  }
  return NO;
}

- (void) checkRegionAndRule {
  NSArray * regions = [offlineMg getLongestStayOfAllTime:300 limit:20];
  for (id regionStr in regions) {
    CLLocation * cl = [self locationStrToLoc:regionStr sep:@"|"];
    if (cl) {
      CLCircularRegion * region = [[CLCircularRegion alloc] initWithCenter:cl.coordinate radius:100.0f identifier:regionStr];
      [locMan startMonitoringForRegion:region];
    }
  }
  
}

@end
