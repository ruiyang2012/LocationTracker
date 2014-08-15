//
//  ProxLocationManager.h
//  clientApiLib
//
//  Created by rui yang on 4/22/14.
//  Copyright (c) 2014 rui yang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ProxLocationManager  : NSObject
- (id) initWithOfflineManager: (id) offlineManger;

- (NSArray*) getLogs;
- (void) resetLogs;
- (BOOL) isCloseToHome;

-(id) getCurLoc;

- (void) checkRegionAndRule;

- (NSTimeInterval) getElapseSinceLastLocationChange;

- (CLLocation *) getHomeLocation;

- (NSString*) placemarkToStr:(CLPlacemark*) pl;

@end
