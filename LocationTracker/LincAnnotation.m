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

}

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
  NSLog(@"selectd button %d", buttonIndex);
  NSArray *venues = [fourSqureResult[@"response"] objectForKey:@"venues"];
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
    [self.offlineMg updateDisplayAddr:self.bucket lat:lat lon:lon name:name
            street:displayAddress city:city state:state country:cc zip:zip];
    
  }
}

- (void) showAddressConfirm {
  if (!_mapView || !fourSqureResult || self.hasConfirmedAddresses) return;

  NSArray *venues = [fourSqureResult[@"response"] objectForKey:@"venues"];
  UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"Please Confirm Your Stay:" delegate:self
                    cancelButtonTitle:nil destructiveButtonTitle:@"Cancel" otherButtonTitles:nil];
  actionSheet.delegate = self;
 

  for (id venue in venues) {
    NSString* name = venue[@"name"];
    [actionSheet addButtonWithTitle:name];

  }
  [actionSheet showInView:_mapView];
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
  self.subtitle = [NSString stringWithFormat:@"stay at %@ for %d mins", v, stay];
}

- (void) updateWithMapView:(MKMapView*)mapView {
  _mapView = mapView;

  if (!geoTool) { geoTool = [[ProxGeoLookUp alloc] init]; }
  if (self.bucket == nil || self.locationDict == nil) return;
  lat = [[self.locationDict objectForKey:@"lat"] doubleValue];
  lon = [[self.locationDict objectForKey:@"lon"] doubleValue];
  stay = [[self.locationDict objectForKey:@"duration"] intValue] / 60;

  self.hasConfirmedAddresses = [[self.locationDict objectForKey:@"hasConfirmedAddress"] boolValue];
  self.curLoc = [[CLLocation alloc] initWithLatitude:lat longitude:lon];
  self.coordinate = self.curLoc.coordinate;
  self.title = [self.locationDict objectForKey:@"name"];
  if (self.hasConfirmedAddresses) {
    [self setSubTitleValue:[self.locationDict objectForKey:@"street"]];
    
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
