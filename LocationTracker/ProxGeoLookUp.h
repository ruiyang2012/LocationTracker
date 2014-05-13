//
//  ProxGeoLookUp.h
//  LocationTracker
//
//  Created by rui yang on 5/12/14.
//  Copyright (c) 2014 Linc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

typedef void (^PROX_GEO_CALLBACK)(NSDictionary* info);

@interface ProxGeoLookUp : NSObject

- (void) fourSquareLookup:(CLLocationCoordinate2D) coord done:(PROX_GEO_CALLBACK) callback;

@end
