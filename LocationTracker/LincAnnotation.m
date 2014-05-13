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
}

- (void) updateWithMapView:(MKMapView*)mapView {
  _mapView = mapView;
  __weak LincAnnotation * weakSelf = self;
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
    self.subtitle = [NSString stringWithFormat:@"stay at %@ for %d mins", [self.locationDict objectForKey:@"street"], stay];
    [mapView addAnnotation:self];
  } else {
    [geoTool fourSquareLookup:self.coordinate done:^(NSDictionary *info) {
        //NSLog(@"four square result: %@", info);
      NSMutableArray * text = [[NSMutableArray alloc] init];
      NSArray *venues = [info[@"response"] objectForKey:@"venues"];
      [text addObject:[NSString stringWithFormat:@"Possible @ %@ for %d mins", [self.locationDict objectForKey:@"street"], stay]];
      for (id venue in venues) {
        NSString* name = venue[@"name"];
          //        NSDictionary* addr = venue[@"location"];
          //        NSString * street = [addr[@"address"] copy];
          //        NSString * city = [addr[@"city"] copy];
          //        NSString * state = [addr[@"state"] copy];
          //        NSString * cc = [addr[@"cc"] copy];
          //        NSString * zip = [addr[@"postalCode"] copy];
        
        
          //[offlineMg updateDisplayAddr:bucket lat:lat lon:lon name:name street:street city:city state:state country:cc zip:zip];
        [text addObject:[NSString stringWithFormat:@"one candidate: %@", name]];
      }
      dispatch_async(dispatch_get_main_queue(), ^{
        self.subtitle = [text componentsJoinedByString:@"\n------\n"];
        [mapView addAnnotation:weakSelf];
      });
      
    }];
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
