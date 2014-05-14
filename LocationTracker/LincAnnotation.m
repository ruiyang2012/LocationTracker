//
//  LincAnnotation.m
//  LocationTracker
//
//  Created by rui yang on 5/13/14.
//  Copyright (c) 2014 Linc. All rights reserved.
//

#import "LincAnnotation.h"
#import "ProxGeoLookUp.h"


@implementation LincAnnotation {
  MKMapView * _mapView;
  double lat;
  double lon;
  int stay;
  ProxGeoLookUp * geoTool;
  NSDictionary* fourSqureResult;
  NSString * displayAddress;
  NSDictionary * bucketDict;

}

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {

  NSArray *venues = [fourSqureResult[@"response"] objectForKey:@"venues"];
  [_mapView deselectAnnotation:self animated:YES];
  NSNotificationCenter *notCenter = [NSNotificationCenter defaultCenter];
  if (buttonIndex > 0) {
    NSDictionary * venue = [venues objectAtIndex:buttonIndex - 1];
    NSString* name = [venue[@"name"] copy];
    NSDictionary* addr = venue[@"location"];
    displayAddress = [addr[@"address"] copy];
    NSString * city = [addr[@"city"] copy];
    NSString * state = [addr[@"state"] copy];
    NSString * cc = [addr[@"cc"] copy];
    NSString * zip = [addr[@"postalCode"] copy];
    self.title = name;

    [self setSubTitleValue:displayAddress];
    self.hasConfirmedAddresses = YES;
    NSString * newBucket = [self.offlineMg updateDisplayAddr:self.bucket lat:lat lon:lon name:name
            street:displayAddress city:city state:state country:cc zip:zip];
    NSDictionary * obj = [[NSDictionary alloc] initWithObjectsAndKeys:self.bucket, @"old", newBucket, @"new", nil];
    [notCenter postNotificationName:@"LincConfirmedAddress" object:obj];
    
  }
}

- (void) showAddressConfirm:(UIView*)inView {
  if (!_mapView || !fourSqureResult || self.hasConfirmedAddresses) return;

  NSArray *venues = [fourSqureResult[@"response"] objectForKey:@"venues"];
  UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"Please Confirm Your Stay:" delegate:self
                    cancelButtonTitle:nil destructiveButtonTitle:@"Cancel" otherButtonTitles:nil];
  actionSheet.delegate = self;
 

  for (id venue in venues) {
    NSString* name = venue[@"name"];
    [actionSheet addButtonWithTitle:name];

  }
  [actionSheet showInView:inView];
}

- (void) show4Squre {
  __weak LincAnnotation * weakSelf = self;
  dispatch_async(dispatch_get_main_queue(), ^{
    NSString * subTitle = [NSString stringWithFormat:@"Possible @ %@ for %d mins", [self.locationDict objectForKey:@"street"], stay];
    self.subtitle = subTitle;

    [_mapView addAnnotation:weakSelf];
  });
}

- (void) setSubTitleValue:(NSString*)v {
  if (stay < 0 ) {
    self.subtitle = [NSString stringWithFormat:@"stay at %@", v];
  } else {
    self.subtitle = [NSString stringWithFormat:@"stay at %@ for %d mins", v, stay];
  }
}

- (void) updateWithMapView:(MKMapView*)mapView {
  _mapView = mapView;

  if (!geoTool) { geoTool = [[ProxGeoLookUp alloc] init]; }
  if (self.bucket == nil) return;
  if (bucketDict == nil && self.locationDict == nil) {
    bucketDict = [self.offlineMg decodeBucket:self.bucket];
  }
  NSDictionary * lookupDic = self.locationDict ? self.locationDict : bucketDict;
  if (lookupDic == nil) return;
  
  
  lat = [[lookupDic objectForKey:@"lat"] doubleValue];
  lon = [[lookupDic objectForKey:@"lon"] doubleValue];
  
  self.curLoc = [[CLLocation alloc] initWithLatitude:lat longitude:lon];
  self.coordinate = self.curLoc.coordinate;
  self.title = [lookupDic objectForKey:@"name"];
  
  if (bucketDict) {
    stay = -1;
    self.hasConfirmedAddresses = YES;
  } else {
    stay = [[self.locationDict objectForKey:@"duration"] intValue] / 60;
    self.hasConfirmedAddresses = [[self.locationDict objectForKey:@"hasConfirmedAddress"] boolValue];
  }

  if (self.hasConfirmedAddresses) {
    [self setSubTitleValue:[lookupDic objectForKey:@"street"]];
    [_mapView addAnnotation:self];
  } else {
    if (fourSqureResult) {
      [self show4Squre];
    } else {
      [geoTool fourSquareLookup:self.coordinate done:^(NSDictionary *info) {
          //NSLog(@"four square result: %@", info);
        fourSqureResult = info;
        [self show4Squre];
      }];
    }
  }
}

- (MKAnnotationView*) getAnnotationView {
  if (!_mapView) return nil;
  static NSString *annotationIdentifier = @"LincAnnotation";
  MKAnnotationView *annotationView = [_mapView dequeueReusableAnnotationViewWithIdentifier:annotationIdentifier];
  if (!annotationView) {
    annotationView = [[MKPinAnnotationView alloc] initWithAnnotation:self reuseIdentifier:annotationIdentifier];
    annotationView.canShowCallout = YES;
      //annotationView.rightCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
  } else {
    annotationView.annotation = self;
  }
  return annotationView;
}




@end
