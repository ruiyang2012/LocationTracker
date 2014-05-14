//
//  LincAnnotation.h
//  LocationTracker
//
//  Created by rui yang on 5/13/14.
//  Copyright (c) 2014 Linc. All rights reserved.
//
#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import "OfflineManager.h"

@interface LincAnnotation : MKPointAnnotation <UIActionSheetDelegate>

@property(nonatomic, strong) NSString *bucket;
@property(nonatomic, strong) NSDictionary *locationDict;
@property(nonatomic, strong) CLLocation * curLoc;
@property(nonatomic, strong) OfflineManager* offlineMg;

@property(atomic, assign) BOOL hasConfirmedAddresses;

- (void) updateWithMapView:(MKMapView*)mapView;
- (MKAnnotationView*) getAnnotationView;
- (void) showAddressConfirm;
@end
