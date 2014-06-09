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

  NSTimeInterval lastLocationUpdate;
  CLLocationManager * locMan;
  CLLocation * curLocation;
  CLLocation * homeLocation;
  NSMutableArray * locLogs;
  int elapse;
  CLRegion * lastRegion;
  NSURLSession * session;
  NSTimeInterval regionEnterTime;
  NSMutableDictionary * homeDict;
}
@end

@implementation ProxLocationManager

- (id) initWithOfflineManager: (id) offlineManger {
  self = [super init];
  offlineMg = offlineManger;
  geocoder = [[CLGeocoder alloc] init];
  curLocation = nil;
  regionEnterTime = lastLocationUpdate = [[NSDate date] timeIntervalSince1970];
  homeDict = [[NSMutableDictionary alloc] init];
  locLogs = [[NSMutableArray alloc] init];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(netStatus:) name:@"ProxOfflineStatusChange" object:nil];
  [self setupLocationManager];
  NSString * homeLocStr = [[NSUserDefaults standardUserDefaults] objectForKey:@"homeLocation"];
  homeLocation = [self locationStrToLoc:homeLocStr sep:@","];
  if (homeLocStr) [homeDict setObject:@(1) forKey:homeLocStr];
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
    //[locMan startMonitoringSignificantLocationChanges];
  [locMan startUpdatingLocation];
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
  dispatch_async(dispatch_get_main_queue(), ^{
    NSArray * arr = [offlineMg getAllUnconfirmedGeo];
    for (id item in arr) {
      NSArray * locArr = [item[0] componentsSeparatedByString:@","];
      NSNumber * time = item[1];
      CLLocation * loc = [[CLLocation alloc] initWithLatitude:[locArr[0] doubleValue] longitude:[locArr[1] doubleValue]];
      [self lookupLocation:loc updateTime:time];
    }
  });
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

- (NSTimeInterval) getElapseSinceLastLocationChange {
  return [[NSDate date] timeIntervalSince1970] - lastLocationUpdate;
}

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation {

  long dist = [newLocation distanceFromLocation:curLocation];

  NSTimeInterval newTime = [[NSDate date] timeIntervalSince1970];
  elapse = (int) (newTime - lastLocationUpdate);
  if (curLocation && newLocation) {
    if (dist < 20 && newLocation.speed > MAX_WALKING_SPEED) return;
    if (dist < 20 && elapse < 10) return;
  }
  [ProxUtils appendToTempfile:@"locDebug" content:[newLocation debugDescription]];

  if (curLocation) {
    NSString * locLog = [NSString stringWithFormat:@"%f,%f,%f",  newTime,
                         curLocation.coordinate.latitude, curLocation.coordinate.longitude];
    [locLogs addObject:locLog];
  }
  [self addLocation:newLocation];
  [self performSelectorOnMainThread:@selector(onLocUpd:) withObject:newLocation waitUntilDone:NO];
}

-(id) getCurLoc {
  return curLocation;
}

- (CLLocation *) getHomeLocation {
  return [homeLocation copy];
}

- (void) onLocUpd:(CLLocation*) loc {
  

  [offlineMg calDeltaInTimeSeries];
    // look up using google place api and four square api here:
  double firstLaunch = [[NSUserDefaults standardUserDefaults] doubleForKey:@"firstLaunch"];
  NSDate * firstLaunchDate = [NSDate dateWithTimeIntervalSince1970:firstLaunch];
  NSInteger daysElapse = [ProxUtils daysBetween:firstLaunchDate to:[NSDate date]];
  NSString * homeStr = [offlineMg getLongestOvernightLocation];
    // short cut here.
  if ((daysElapse <= 0 && homeLocation != nil) || homeStr == nil) { return; }
  NSNumber * homeCnt = [homeDict objectForKey:homeStr];
  if (!homeCnt) homeCnt = @(0);
  homeCnt = [NSNumber numberWithInt:1 + [homeCnt intValue]];
  [homeDict setObject:homeCnt forKey:homeStr];
    // find largest number.
  int maxCnt = 0;
  for (NSString * k in homeDict) {
    NSNumber * v = [homeDict objectForKey:k];
    if (maxCnt < [v intValue]) {
      homeStr = k;
      maxCnt = [v intValue];
    }
  }
  [[NSUserDefaults standardUserDefaults] setObject:homeStr forKey:@"homeLocation"];

  homeLocation = [self locationStrToLoc:homeStr sep:@","];
}

- (void) addLocation:(id) loc {
  if (offlineMg == nil) return;

  NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
  CLLocation * curLoc = (CLLocation *) loc;

  NSString * locStr = [self locationToLatLonStr:curLoc];
  NSNumber * nowNum = [NSNumber numberWithLong:now];
  NSNumber * speed = [NSNumber numberWithInt:curLoc.speed];
  [offlineMg setLoc:locStr type:@"raw_data" time:nowNum speed:speed];
  lastLocationUpdate = now;
  if (![offlineMg isOffline] && curLoc.speed < MAX_WALKING_SPEED) {
    [self lookupLocation:curLoc updateTime:nowNum];
  }
  

  [self dispatchLocationChange:curLocation to:curLoc duration:elapse];
  curLocation = curLoc;
}

- (void) gapiLookup:(CLLocation*) loc updateTime:(NSNumber*) updTime {
  [geocoder reverseGeocodeLocation:loc completionHandler:^(NSArray *placemarks, NSError *error) {
    if (error || [placemarks count] ==0) {
      NSLog(@"location lookup error: %@ or no place", error);
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

- (void) lookupLocation:(CLLocation *) loc updateTime:(NSNumber*) updTime {
  NSString * gapi = [NSString stringWithFormat:@"%@%f,%f", GAPI_BASE_URL, loc.coordinate.latitude, loc.coordinate.longitude];
  NSURL * url = [NSURL URLWithString:gapi];
  [[session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
    if (error) {
        // nslog
      [self gapiLookup:loc updateTime:updTime];
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
    NSArray * addrComponents = addr[@"address_components"];
    NSString * streetNo = @"";
    NSString * street = @"";
    NSString * locality = @"";
    NSString * city = @"";
    NSString * state = @"";
    NSString * cc = @"";
    NSString * zip = @"";
    NSString * name = @"";
    
    for (id c in addrComponents) {
      NSArray * addrType = c[@"types"];
      if ([addrType containsObject:@"street_number"]) {
        streetNo = c[@"short_name"];
      } else if ([addrType containsObject:@"route"]) {
        name = c[@"short_name"];
      } else if ([addrType containsObject:@"locality"]) {
        locality = c[@"short_name"];
      } else if ([addrType containsObject:@"administrative_area_level_3"]) {
        city = c[@"short_name"];
      } else if ([addrType containsObject:@"administrative_area_level_1"]) {
        state = c[@"short_name"];
      } else if ([addrType containsObject:@"country"]) {
        cc = c[@"short_name"];
      }  else if ([addrType containsObject:@"postal_code"]) {
        zip = c[@"short_name"];
      }
    }
    if ([ProxUtils isEmptyString:city]) city = locality;
    if ([ProxUtils isEmptyString:city] || [ProxUtils isEmptyString:name]) {
      [self gapiLookup:loc updateTime:updTime];
      return;
    }
    street = [NSString stringWithFormat:@"%@ %@", streetNo, name];
    NSArray * locArr = @[lat, lon, name, street, city, state, cc, zip];
    NSString * locStr = [locArr componentsJoinedByString:@"|"];
    [offlineMg updateTimeSeriesType:@"raw_data_confirmed" key:[self locationToLatLonStr:loc]];
    NSNumber * speed = [NSNumber numberWithInt:loc.speed];
    [offlineMg setLoc:locStr type:@"apple_map" time:updTime speed:speed];
    [offlineMg calDeltaInTimeSeries];
  }] resume];
  

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
